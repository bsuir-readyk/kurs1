unit schema;

interface

uses
  SysUtils, types, fs;

// Функция для парсинга схемы SQL
function ParseSchema(const SqlCode: string): TSchema;

function SplitSqlFields(const FieldsStr: string): TStringArray;

implementation

const
  SQL_TABLE_DELIMITER = 'CREATE';
  SQL_TABLE_NAME_REGEX_PATTERN = '(TABLE|table)\s+(\w+)';

// Функция для извлечения имени таблицы из SQL-кода
function ExtractTableName(const TableDeclaration: string): string;
var
  StartPos, EndPos: Integer;
begin
  StartPos := Pos('TABLE', UpperCase(TableDeclaration));
  if StartPos = 0 then
    StartPos := Pos('table', TableDeclaration);
  
  if StartPos > 0 then
  begin
    // Пропускаем слово "TABLE" или "table"
    StartPos := StartPos + 5;
    // Пропускаем пробелы
    while (StartPos <= Length(TableDeclaration)) and (TableDeclaration[StartPos] = ' ') do
      Inc(StartPos);
    
    // Извлекаем имя таблицы
    EndPos := StartPos;
    while (EndPos <= Length(TableDeclaration)) and 
          ((TableDeclaration[EndPos] >= 'a') and (TableDeclaration[EndPos] <= 'z') or
           (TableDeclaration[EndPos] >= 'A') and (TableDeclaration[EndPos] <= 'Z') or
           (TableDeclaration[EndPos] >= '0') and (TableDeclaration[EndPos] <= '9') or
           (TableDeclaration[EndPos] = '_')) do
      Inc(EndPos);
    
    Result := Copy(TableDeclaration, StartPos, EndPos - StartPos);
  end
  else
    Result := '';
end;

// Функция для удаления комментариев из SQL-кода
function RemoveComments(const SqlCode: string): string; // FIXME
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
  result := res;
end;

// Функция для парсинга схемы SQL
function ParseSchema(const SqlCode: string): TSchema;
var
  CleanSqlCode: string;
  TableDeclarations: array of string;
  i, j, k, TableCount, FieldCount: Integer;
  TableName, FieldLine, FieldName, FieldType: string;
  IsNullable: Boolean;
  StartPos, EndPos: Integer;
  FieldLines: TStringArray;
begin
  // Удаление комментариев
  CleanSqlCode := RemoveComments(SqlCode);
  
  // Разделение SQL-кода на объявления таблиц
  i := 1;
  TableCount := 0;
  SetLength(TableDeclarations, 0);
  
  while i <= Length(CleanSqlCode) do
  begin
    j := Pos(SQL_TABLE_DELIMITER, UpperCase(Copy(CleanSqlCode, i, Length(CleanSqlCode))));
    if j > 0 then
      j := j + i - 1;
    if j = 0 then
      Break;
    
    i := j;
    j := Pos(';', Copy(CleanSqlCode, i, Length(CleanSqlCode)));
    if j > 0 then
      j := j + i - 1;
    if j = 0 then
      Break;
    
    SetLength(TableDeclarations, TableCount + 1);
    TableDeclarations[TableCount] := Copy(CleanSqlCode, i, j - i + 1);
    Inc(TableCount);
    i := j + 1;
  end;
  
  // Извлечение имен таблиц и полей
  SetLength(Result, TableCount);
    
    for i := 0 to TableCount - 1 do
    begin
      // Извлечение имени таблицы
      Result[i].Name := ExtractTableName(TableDeclarations[i]);
      if Result[i].Name = '' then
        raise Exception.Create('Cant find table name in declaration: ' + TableDeclarations[i]);
      
      // Извлечение полей таблицы
      StartPos := Pos('(', TableDeclarations[i]) + 1;
      EndPos := LastDelimiter(')', TableDeclarations[i]) - 1;
      if (StartPos <= 0) or (EndPos <= 0) or (EndPos < StartPos) then
        Continue;
      
      FieldLine := Copy(TableDeclarations[i], StartPos, EndPos - StartPos + 1);
      
      // Разделение на поля с учетом скобок
      FieldCount := 0;
      
      // Более умный алгоритм разделения на поля
      // Учитывает скобки и не разделяет запятые внутри скобок
      FieldLines := SplitSqlFields(FieldLine);
      
      for j := 0 to Length(FieldLines) - 1 do
      begin
        FieldLine := Trim(FieldLines[j]);
          if FieldLine = '' then
            Continue;
          
          // Извлечение имени и типа поля
          k := Pos(' ', FieldLine);
          if k > 0 then
          begin
            FieldName := Trim(Copy(FieldLine, 1, k - 1));
            FieldType := Trim(Copy(FieldLine, k + 1, Length(FieldLine) - k));
            
            // Извлекаем только первое слово как тип
            k := Pos(' ', FieldType);
            if k > 0 then
              FieldType := Trim(Copy(FieldType, 1, k - 1));
            
            IsNullable := (Pos('NOT NULL', UpperCase(FieldLine)) = 0) and 
                          (Pos('PRIMARY KEY', UpperCase(FieldLine)) = 0);
            
            if not IsAllowedSqlColumnType(UpperCase(FieldType)) then
              raise Exception.Create('ParseSchema: Unsupported column type. Got: "' + FieldType + '" on line "' + FieldLine + '"');
            
            // Добавление поля в таблицу
            SetLength(Result[i].Columns, FieldCount + 1);
            Result[i].Columns[FieldCount].Name := FieldName;
            
            if UpperCase(FieldType) = 'TEXT' then
              Result[i].Columns[FieldCount].ColumnType := ctText
            else if UpperCase(FieldType) = 'INTEGER' then
              Result[i].Columns[FieldCount].ColumnType := ctInteger;
            
            Result[i].Columns[FieldCount].Nullable := IsNullable;
            
            Inc(FieldCount);
          end;
        end;
    end;
end;

// Функция для разделения SQL-полей с учетом скобок
function SplitSqlFields(const FieldsStr: string): TStringArray;
var
  i, j, BracketLevel, Count: Integer;
  CurrentField: string;
  Fields: array of string;
begin
  SetLength(Fields, 0);
  Count := 0;
  BracketLevel := 0;
  CurrentField := '';
  
  i := 1;
  while i <= Length(FieldsStr) do
  begin
    case FieldsStr[i] of
      '(': Inc(BracketLevel);
      ')': Dec(BracketLevel);
      ',':
        if BracketLevel = 0 then
        begin
          // Запятая вне скобок - разделитель полей
          SetLength(Fields, Count + 1);
          Fields[Count] := Trim(CurrentField);
          Inc(Count);
          CurrentField := '';
          Inc(i);
          Continue;
        end;
    end;
    
    CurrentField := CurrentField + FieldsStr[i];
    Inc(i);
  end;
  
  // Добавляем последнее поле
  if CurrentField <> '' then
  begin
    SetLength(Fields, Count + 1);
    Fields[Count] := Trim(CurrentField);
  end;
  
  Result := Fields;
end;

end.
