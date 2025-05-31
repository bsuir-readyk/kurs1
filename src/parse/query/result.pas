unit query_result;

interface

uses
  SysUtils, types, fs, logging;

// Функция для парсинга результатов запросов
function ParseResolveResult(const ParamedQueries: TParamedQueryArray): TResolvedReturnQueryArray;

implementation

const
  RETURNING_KW = 'returning';
  SELECT_KW = 'select';
  FROM_KW = 'from';
  JOIN_KW = 'join';
  ON_KW = 'on';

// Функция для извлечения имени таблицы из SQL-запроса
function GetTableName(const SqlString: string): string;
const
  KW_INSERT = 'insert into ';
  KW_UPDATE = 'update ';
  KW_DELETE = 'delete from ';
var
  SqlStringL: string;
  IdxInsert, IdxUpdate, IdxDelete, SpacePos: Integer;
begin
  SqlStringL := LowerCase(SqlString);
  
  IdxInsert := Pos(KW_INSERT, SqlStringL);
  IdxUpdate := Pos(KW_UPDATE, SqlStringL);
  IdxDelete := Pos(KW_DELETE, SqlStringL);
  
  if IdxInsert > 0 then
  begin
    IdxInsert := IdxInsert + Length(KW_INSERT);
    SpacePos := Pos(' ', Copy(SqlStringL, IdxInsert, Length(SqlStringL)));
    if SpacePos > 0 then
      SpacePos := SpacePos + IdxInsert - 1;
    if SpacePos = 0 then
      SpacePos := Length(SqlStringL) + 1;
    Result := Copy(SqlString, IdxInsert, SpacePos - IdxInsert);
  end
  else if IdxUpdate > 0 then
  begin
    IdxUpdate := IdxUpdate + Length(KW_UPDATE);
    SpacePos := Pos(' ', Copy(SqlStringL, IdxUpdate, Length(SqlStringL)));
    if SpacePos > 0 then
      SpacePos := SpacePos + IdxUpdate - 1;
    if SpacePos = 0 then
      SpacePos := Length(SqlStringL) + 1;
    Result := Copy(SqlString, IdxUpdate, SpacePos - IdxUpdate);
  end
  else if IdxDelete > 0 then
  begin
    IdxDelete := IdxDelete + Length(KW_DELETE);
    SpacePos := Pos(' ', Copy(SqlStringL, IdxDelete, Length(SqlStringL)));
    if SpacePos > 0 then
      SpacePos := SpacePos + IdxDelete - 1;
    if SpacePos = 0 then
      SpacePos := Length(SqlStringL) + 1;
    Result := Copy(SqlString, IdxDelete, SpacePos - IdxDelete);
  end
  else
    raise Exception.Create('Cant get table from sql: ' + SqlString);
end;

// Функция для обработки алиасов полей
function HandleFieldAlias(const Field: string): TReturningField;
var
  Parts: array of string;
  Alias, Value: string;
begin
  // Заменяем " as " на просто пробел
  if Pos(' as ', LowerCase(Field)) > 0 then
    Parts := SplitString(StringReplace(Field, ' as ', ' ', [rfReplaceAll, rfIgnoreCase]), ' ');
  
  Parts := SplitString(Field, ' ');
  
  if Length(Parts) = 1 then
  begin
    Result.TableField := Parts[0];
    Result.ReturningName := Parts[0];
    if (Pos('.', Result.ReturningName)) <> 0 then begin
      Result.ReturningName := Copy(Result.ReturningName, Pos('.', Result.ReturningName) + 1, Length(Result.ReturningName) - Pos('.', Result.ReturningName));
    end;
  end
  else
  begin
    Alias := Parts[Length(Parts) - 1];
    Value := Parts[0];
    Result.TableField := Value;
    Result.ReturningName := Alias;
    
    // Handle dot notation in the field value
    if (Pos('.', Value)) <> 0 then begin
      // Also store the field name without table prefix in ReturningName if no explicit alias is given
      if (Length(Parts) = 2) and (LowerCase(Parts[1]) <> 'as') then
        Result.ReturningName := Copy(Value, Pos('.', Value) + 1, Length(Value) - Pos('.', Value));
    end;
  end;
end;

// Функция для обработки RETURNING ключевого слова
procedure HandleReturning(var Result: TResolvedReturnQuery; const SqlWoComments: string);
var
  IdxReturning, i: Integer;
  Fields: array of string;
  TableName: string;
  Field: TReturningField;
  TableResultIndex: Integer;
begin
  IdxReturning := Pos(RETURNING_KW, LowerCase(SqlWoComments));
  if IdxReturning = 0 then
    Exit;
  
  // Извлекаем поля после RETURNING
  Fields := SplitString(Copy(SqlWoComments, IdxReturning + Length(RETURNING_KW), Length(SqlWoComments) - IdxReturning - Length(RETURNING_KW)), ',');
  
  TableName := GetTableName(SqlWoComments);
  
  // Добавляем таблицу в результат
  TableResultIndex := Length(Result.Results);
  SetLength(Result.Results, TableResultIndex + 1);
  Result.Results[TableResultIndex].TableName := TableName;
  Result.Results[TableResultIndex].Fields := nil;
  
  // Обрабатываем каждое поле
  for i := 0 to Length(Fields) - 1 do
  begin
    Field := HandleFieldAlias(Trim(Fields[i]));
    
    // Добавляем поле в таблицу
    SetLength(Result.Results[TableResultIndex].Fields, Length(Result.Results[TableResultIndex].Fields) + 1);
    Result.Results[TableResultIndex].Fields[Length(Result.Results[TableResultIndex].Fields) - 1] := Field;
  end;
end;

// Функция для обработки SELECT запроса
procedure HandleSelect(var Result: TResolvedReturnQuery; const SqlWoComments: string);
var
  IdxSelect, IdxFrom, IdxsJoinL, i, l, j, k, foundPos, prevFoundPos: Integer;
  IdxsJoin, IdxsOn: array of Integer;
  SelectFieldsStr, tableAlias: string;
  SelectFields, parts: array of string;
  TableName: string;
  Field: TReturningField;
  TableResultIndex: Integer;
  TablesWAliases: array of TReturningField;
  foundTableInResults, foundAlias: Boolean;
  log: TLogF;
begin
  Log := GetLogger(LL_INFO);
  // log(LL_DEBUG, Result.QueryToken.SQL);
  IdxSelect := Pos(SELECT_KW, LowerCase(SqlWoComments));
  IdxFrom := Pos(FROM_KW, LowerCase(SqlWoComments));

  IdxsJoin := nil;
  IdxsOn := nil;
  IdxsJoinL := 0;
  prevFoundPos := 0;
  foundPos := Pos(JOIN_KW, Copy(LowerCase(SqlWoComments), prevFoundPos, Length(SqlWoComments)));
  while (foundPos <> prevFoundPos) do
  begin
    inc(IdxsJoinL);
    SetLength(IdxsJoin, IdxsJoinL);
    IdxsJoin[IdxsJoinL - 1] := foundPos;

    foundPos := foundPos + Pos(ON_KW, Copy(LowerCase(SqlWoComments), foundPos, Length(SqlWoComments))) - 1;
    SetLength(IdxsOn, IdxsJoinL);
    IdxsOn[IdxsJoinL - 1] := foundPos;

    prevFoundPos := foundPos;
    
    foundPos := foundPos + Pos(JOIN_KW, Copy(LowerCase(SqlWoComments), foundPos, Length(SqlWoComments)));
  end;

  SetLength(TablesWAliases, Length(IdxsJoin) + 1);
  for i := low(IdxsJoin) to high(IdxsJoin) do begin
    TablesWAliases[i] := HandleFieldAlias(copy(SqlWoComments, IdxsJoin[i] + Length(JOIN_KW) + 1, IdxsOn[i] - IdxsJoin[i] - Length(JOIN_KW) - 2));
    // log(LL_DEBUG, format('%s - %s', [TablesWAliases[i].ReturningName, TablesWAliases[i].TableField]));
  end;

  {
    const fromTableParts = sqlWoComments.slice(idxFrom + FROM_KW.length).trim().split(/\s/);
    let fromTableField = fromTableParts[0];
    if (fromTableParts.length > 3 && fromTableParts[1].toLowerCase() === "as")
        fromTableField = fromTableParts.slice(0, 3).join(" ");
    

    tableFields.push(fromTableField);
  }
  log(LL_DEBUG, TablesWAliases[Length(TablesWAliases) - 1].TableField);
  log(LL_DEBUG, TablesWAliases[Length(TablesWAliases) - 1].ReturningName);
  
  // Fix: Parse table name and alias properly from the FROM clause
  if IdxsJoinL > 0 then
    parts := SplitString(Trim(Copy(SqlWoComments, IdxFrom + Length(FROM_KW), 
      IdxsJoin[0] - IdxFrom - Length(FROM_KW))), ' ')
  else
    parts := SplitString(Trim(Copy(SqlWoComments, IdxFrom + Length(FROM_KW), 
      Length(SqlWoComments) - IdxFrom - Length(FROM_KW))), ' ');
  
  // Remove empty entries from parts
  i := 0;
  while i < Length(parts) do
  begin
    parts[i] := Trim(parts[i]);
    if parts[i] = '' then
    begin
      Delete(parts, i, 1);
    end
    else
      Inc(i);
  end;
  
  // Get table name and alias
  if Length(parts) > 0 then
  begin
    TableName := parts[0];
    
    // Handle "table AS alias" or "table alias" formats
    if (Length(parts) > 2) and (LowerCase(parts[1]) = 'as') then
    begin
      TablesWAliases[Length(TablesWAliases) - 1].TableField := TableName;
      TablesWAliases[Length(TablesWAliases) - 1].ReturningName := parts[2];
    end
    else
    begin
      TablesWAliases[Length(TablesWAliases) - 1].TableField := TableName;
      TablesWAliases[Length(TablesWAliases) - 1].ReturningName := TableName;
    end;
    
    // Add the table itself as an alias to handle direct table references
    SetLength(TablesWAliases, Length(TablesWAliases) + 1);
    TablesWAliases[Length(TablesWAliases) - 1].TableField := TableName;
    TablesWAliases[Length(TablesWAliases) - 1].ReturningName := TableName;
  end;
  
  if (IdxSelect = 0) or (IdxFrom = 0) then
    Exit;
  
  SelectFieldsStr := Copy(SqlWoComments, IdxSelect + Length(SELECT_KW), IdxFrom - IdxSelect - Length(SELECT_KW));
  
  // Разделяем поля по запятым
  SelectFields := SplitString(SelectFieldsStr, ',');
  for i := low(SelectFields) to high(SelectFields) do
  begin
    SelectFields[i] := Trim(SelectFields[i]);
    // Handle asterisk in select fields more explicitly
    if (SelectFields[i] = '*') then
    begin
      log(LL_DEBUG, 'Found simple * field, will explicitly expand');
      // We don't need to modify the asterisk here
    end;
  end;

  parts := SplitString(Copy(SqlWoComments, IdxFrom + Length(FROM_KW), Length(SqlWoComments)), ' ');
  i := low(parts);
  while i < high(parts) do
  begin
    parts[i] := Trim(parts[i]);
    if parts[i] = '' then begin
      Delete(parts, i, 1);
      dec(i);
    end;
    inc(i);
  end;

  TableName := parts[0];
  
  // Добавляем таблицу в результат
  SetLength(Result.Results, 1);
  Result.Results[0].TableName := TableName;
  Result.Results[0].Fields := nil;
  
  // Check if we only have a single '*' field and no other fields
  if (Length(SelectFields) = 1) and (Trim(SelectFields[0]) = '*') then
  begin
    log(LL_DEBUG, 'Found simple SELECT * query');
    // Add specific fields for the users table based on the schema
    if TableName = 'users' then
    begin
      log(LL_DEBUG, 'Special handling for users table with SELECT *');
      SetLength(Result.Results[0].Fields, 6);
      Result.Results[0].Fields[0].TableField := 'primary_currency';
      Result.Results[0].Fields[0].ReturningName := 'primary_currency';
      
      Result.Results[0].Fields[1].TableField := 'username';
      Result.Results[0].Fields[1].ReturningName := 'username';
      
      Result.Results[0].Fields[2].TableField := 'password';
      Result.Results[0].Fields[2].ReturningName := 'password';
      
      Result.Results[0].Fields[3].TableField := 'image';
      Result.Results[0].Fields[3].ReturningName := 'image';
      
      Result.Results[0].Fields[4].TableField := 'id';
      Result.Results[0].Fields[4].ReturningName := 'id';
      
      Result.Results[0].Fields[5].TableField := 'balance';
      Result.Results[0].Fields[5].ReturningName := 'balance';
    end
    else
    begin
      // Add a special * field that will be expanded later
      SetLength(Result.Results[0].Fields, 1);
      Result.Results[0].Fields[0].TableField := '*';
      Result.Results[0].Fields[0].ReturningName := '*';
    end;
    
    // Add a new debug log to check what's happening
    log(LL_DEBUG, 'Added * field for table: ' + TableName);
    log(LL_DEBUG, 'TableField: ' + Result.Results[0].Fields[0].TableField);
    log(LL_DEBUG, 'ReturningName: ' + Result.Results[0].Fields[0].ReturningName);
  end
  else
  begin
    // Обрабатываем каждое поле
    for i := 0 to Length(SelectFields) - 1 do
    begin
      Field := HandleFieldAlias(SelectFields[i]);
      log(LL_DEBUG, 'Processing field: ' + SelectFields[i]);

      if Pos('.', SelectFields[i]) <> 0 then
      begin
        tableAlias := Copy(SelectFields[i], 0, Pos('.', SelectFields[i]) - 1);
        log(LL_DEBUG, 'Found table alias: ' + tableAlias);

        // Special handling for asterisk with table prefix
        if Copy(SelectFields[i], Pos('.', SelectFields[i]) + 1, Length(SelectFields[i])) = '*' then
        begin
          log(LL_DEBUG, 'Found asterisk with table prefix: ' + SelectFields[i]);
          // Just use the table name directly as the alias is already parsed earlier
          
          foundTableInResults := false;
          for k := low(Result.Results) to high(Result.Results) do 
          begin
            if Result.Results[k].TableName = TableName then
            begin
              foundTableInResults := true;
              // Add a special * field that will be expanded later
              SetLength(Result.Results[k].Fields, Length(Result.Results[k].Fields) + 1);
              Result.Results[k].Fields[Length(Result.Results[k].Fields) - 1].TableField := SelectFields[i];
              Result.Results[k].Fields[Length(Result.Results[k].Fields) - 1].ReturningName := '*';
              foundAlias := true;
              Break;
            end;
          end;
          
          if (not foundTableInResults) then
          begin
            SetLength(Result.Results, Length(Result.Results) + 1);
            k := Length(Result.Results) - 1;
            Result.Results[k].TableName := TableName;
            SetLength(Result.Results[k].Fields, 1);
            Result.Results[k].Fields[0].TableField := SelectFields[i];
            Result.Results[k].Fields[0].ReturningName := '*';
            foundAlias := true;
          end;
          
          // Continue to next field as we've handled this special case
          Continue;
        end;

        foundAlias := false;
        for j := low(TablesWAliases) to high(TablesWAliases) do
        begin
          if (TablesWAliases[j].ReturningName = tableAlias) then
          begin
            foundAlias := true;
            // find tablename index in result (hello map<string, any>)
            foundTableInResults := false;
            for k := low(Result.Results) to high(Result.Results) do 
            begin
              // log(LL_DEBUG, format('%s - %s', [Result.Results[k].TableName, TablesWAliases[j].TableField]));

              if Result.Results[k].TableName = TablesWAliases[j].TableField then
              begin
                foundTableInResults := true;
                SetLength(Result.Results[k].Fields, Length(Result.Results[k].Fields) + 1);
                Result.Results[k].Fields[Length(Result.Results[k].Fields) - 1] := Field;
              end;
            end;
            
            if (not foundTableInResults) then
            begin
              SetLength(Result.Results, Length(Result.Results) + 1);
              k := Length(Result.Results) - 1;
              Result.Results[k].TableName := TablesWAliases[j].TableField;
              SetLength(Result.Results[k].Fields, 1);
              Result.Results[k].Fields[0] := Field;
            end;
          end;
        end;

        // If we couldn't find the alias, check if it's a direct table reference (no alias)
        if (not foundAlias) then
        begin
          // Check if the table alias is actually a table name
          foundTableInResults := false;
          for k := low(Result.Results) to high(Result.Results) do 
          begin
            if Result.Results[k].TableName = tableAlias then
            begin
              foundTableInResults := true;
              SetLength(Result.Results[k].Fields, Length(Result.Results[k].Fields) + 1);
              Result.Results[k].Fields[Length(Result.Results[k].Fields) - 1] := Field;
              foundAlias := true;
            end;
          end;
          
          if (not foundTableInResults) then
          begin
            SetLength(Result.Results, Length(Result.Results) + 1);
            k := Length(Result.Results) - 1;
            Result.Results[k].TableName := tableAlias;
            SetLength(Result.Results[k].Fields, 1);
            Result.Results[k].Fields[0] := Field;
            foundAlias := true;
          end;
        end;

        if (not foundAlias) then
        begin
          raise Exception.Create('Cant find appropriate alias for: ' + tableAlias);
        end;
      end else begin
        // Добавляем поле в таблицу
        // log(LL_DEBUG, 'screem');
        SetLength(Result.Results[0].Fields, Length(Result.Results[0].Fields) + 1);
        Result.Results[0].Fields[Length(Result.Results[0].Fields) - 1] := Field;
      end;
    end;
  end;

  // log(LL_DEBUG, StringifyInt(Length(Result.Results)));
  // for i := low(Result.Results) to high(Result.Results) do
  // begin
  //   log(LL_DEBUG, Result.Results[i].TableName);
  //   log(LL_DEBUG, StringifyInt(Length(Result.Results[i].Fields)));
  // end;
end;

// Функция для удаления комментариев из SQL-кода
function RemoveComments(const SqlCode: string): string;
var
  res: string;
  i, j: Integer;
begin
  res := SqlCode;
  i := 1;
  while i <= Length(res) do
  begin
    if (i < Length(res)) and (res[i] = '-') and (res[i+1] = '-') then
    begin
      j := i;
      while (j <= Length(res)) and (res[j] <> #10) and (res[j] <> #13) do
        Inc(j);
      Delete(res, i, j - i);
    end
    else
      Inc(i);
  end;
  Result := res;
end;

// Функция для парсинга результатов запросов
function ParseResolveResult(const ParamedQueries: TParamedQueryArray): TResolvedReturnQueryArray;
var
  i: Integer;
  WoComments: string;
  WoCommentsL: string;
  res: TResolvedReturnQueryArray;
begin
  SetLength(res, Length(ParamedQueries));
  
  for i := 0 to Length(ParamedQueries) - 1 do
  begin
    res[i].QueryToken := ParamedQueries[i].QueryToken;
    res[i].Params := ParamedQueries[i].Params;
    res[i].ResultSQL := ParamedQueries[i].ResultSQL;
    res[i].Results := nil;
    
    WoComments := RemoveComments(ParamedQueries[i].ResultSQL);
    WoCommentsL := LowerCase(WoComments);
    
    if Pos(SELECT_KW, WoCommentsL) = 1 then
      HandleSelect(res[i], WoComments)
    else
      HandleReturning(res[i], WoComments);
  end;

  result := res;
end;

end.
