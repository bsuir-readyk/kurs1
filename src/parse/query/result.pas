unit query_result;

interface

uses
  SysUtils, types, fs;

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
  IdxSelect, IdxFrom, i: Integer;
  SelectFieldsStr: string;
  SelectFields: array of string;
  TableName: string;
  Field: TReturningField;
  TableResultIndex: Integer;
begin
  IdxSelect := Pos(SELECT_KW, LowerCase(SqlWoComments));
  IdxFrom := Pos(FROM_KW, LowerCase(SqlWoComments));
  
  if (IdxSelect = 0) or (IdxFrom = 0) then
    Exit;
  
  SelectFieldsStr := Copy(SqlWoComments, IdxSelect + Length(SELECT_KW), IdxFrom - IdxSelect - Length(SELECT_KW));
  
  // Разделяем поля по запятым
  SelectFields := SplitString(SelectFieldsStr, ',');
  
  // Получаем имя таблицы (упрощенно, берем первую таблицу после FROM)
  // FIXME
  TableName := '';
  i := IdxFrom + Length(FROM_KW);
  while (i <= Length(SqlWoComments)) and (SqlWoComments[i] = ' ') do
    Inc(i);
  
  while (i <= Length(SqlWoComments)) and
        ((SqlWoComments[i] >= 'a') and (SqlWoComments[i] <= 'z') or
         (SqlWoComments[i] >= 'A') and (SqlWoComments[i] <= 'Z') or
         (SqlWoComments[i] >= '0') and (SqlWoComments[i] <= '9') or
         (SqlWoComments[i] = '_')) do
  begin
    TableName := TableName + SqlWoComments[i];
    Inc(i);
  end;
  
  // Добавляем таблицу в результат
  TableResultIndex := Length(Result.Results);
  SetLength(Result.Results, TableResultIndex + 1);
  Result.Results[TableResultIndex].TableName := TableName;
  Result.Results[TableResultIndex].Fields := nil;
  
  // Обрабатываем каждое поле
  for i := 0 to Length(SelectFields) - 1 do
  begin
    Field := HandleFieldAlias(Trim(SelectFields[i]));
    
    // Добавляем поле в таблицу
    SetLength(Result.Results[TableResultIndex].Fields, Length(Result.Results[TableResultIndex].Fields) + 1);
    Result.Results[TableResultIndex].Fields[Length(Result.Results[TableResultIndex].Fields) - 1] := Field;
  end;
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
