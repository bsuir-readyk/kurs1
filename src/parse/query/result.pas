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
      Result.ReturningName := Copy(Result.ReturningName, Pos('.', Result.ReturningName) + 1, Length(Result.ReturningName));
    end;
  end
  else
  begin
    Alias := Parts[Length(Parts) - 1];
    Value := Parts[0];
    Result.TableField := Value;
    Result.ReturningName := Alias;
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
  log := GetLogger(LL_NO_LOGS);
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

  SetLength(TablesWAliases, Length(IdxsJoin));
  for i := low(IdxsJoin) to high(IdxsJoin) do begin
    TablesWAliases[i] := HandleFieldAlias(copy(SqlWoComments, IdxsJoin[i] + Length(JOIN_KW) + 1, IdxsOn[i] - IdxsJoin[i] - Length(JOIN_KW) - 2));
    // log(LL_DEBUG, format('%s - %s', [TablesWAliases[i].ReturningName, TablesWAliases[i].TableField]));
  end;
  
  if (IdxSelect = 0) or (IdxFrom = 0) then
    Exit;
  
  SelectFieldsStr := Copy(SqlWoComments, IdxSelect + Length(SELECT_KW), IdxFrom - IdxSelect - Length(SELECT_KW));
  
  // Разделяем поля по запятым
  SelectFields := SplitString(SelectFieldsStr, ',');
  for i := low(SelectFields) to high(SelectFields) do
  begin
    SelectFields[i] := Trim(SelectFields[i]);
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

  if (Length(parts) > 3) and (LowerCase(parts[1]) = 'as') then 
  begin
    SetLength(TablesWAliases, Length(TablesWAliases) + 1);
    TablesWAliases[Length(TablesWAliases) - 1].TableField := parts[0];
    TablesWAliases[Length(TablesWAliases) - 1].ReturningName := parts[2];
  end;

  TableName := parts[0];
  
  // Добавляем таблицу в результат
  SetLength(Result.Results, 1);
  Result.Results[0].TableName := TableName;
  Result.Results[0].Fields := nil;
  
  // Обрабатываем каждое поле
  for i := 0 to Length(SelectFields) - 1 do
  begin
    Field := HandleFieldAlias(SelectFields[i]);

    if Pos('.', SelectFields[i]) <> 0 then
    begin
      tableAlias := Copy(SelectFields[i], 0, Pos('.', SelectFields[i]) - 1);

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
            SetLength(Result.Results[k].Fields, Length(Result.Results[k].Fields) + 1);
            Result.Results[k].Fields[Length(Result.Results[k].Fields) - 1] := Field;
          end;

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
