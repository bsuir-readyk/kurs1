unit query_gen;

interface

uses
  SysUtils, types, return_one, return_many, return_exec;

// Функция для генерации кода запросов
function GenerateQueryFile(const Queries: array of TResolvedReturnQuery; const Schema: TSchema; const PackageName: string): string;

implementation

// Функция для преобразования первой буквы строки в верхний регистр
function Capitalize(const S: string): string;
begin
  if S = '' then
    Result := ''
  else
    Result := UpperCase(S[1]) + Copy(S, 2, Length(S) - 1);
end;

// Константа с именем текущего модуля для логирования
const
  MODULE_NAME = 'query_gen';

// Функция для получения полей результата запроса
function GetResultFields(const Query: TResolvedReturnQuery; const Schema: TSchema): TStringArray;
var
  ResultFields: TStringArray;
  i, j, k, m, FieldCount: Integer;
  TableName, FieldName: string;
  Found: Boolean;
begin
  ResultFields := nil;
  FieldCount := 0;
  
  for i := 0 to Length(Query.Results) - 1 do
  begin
    TableName := Query.Results[i].TableName;
    
    for j := 0 to Length(Query.Results[i].Fields) - 1 do
    begin
      FieldName := Query.Results[i].Fields[j].TableField;
      
      if FieldName = '*' then
      begin
        // Если поле - звездочка, добавляем все поля таблицы
        for k := 0 to Length(Schema) - 1 do
        begin
          if Schema[k].Name = TableName then
          begin
            SetLength(ResultFields, FieldCount + Length(Schema[k].Columns));
            
            for m := 0 to Length(Schema[k].Columns) - 1 do
            begin
              ResultFields[FieldCount] := Capitalize(Schema[k].Columns[m].Name);
              Inc(FieldCount);
            end;
            
            Break;
          end;
        end;
      end
      else
      begin
        // Если поле - конкретное имя, добавляем его
        SetLength(ResultFields, FieldCount + 1);
        ResultFields[FieldCount] := Capitalize(Query.Results[i].Fields[j].ReturningName);
        Inc(FieldCount);
      end;
    end;
  end;
  
  Result := ResultFields;
end;

// Функция для генерации кода запросов
function GenerateQueryFile(const Queries: array of TResolvedReturnQuery; const Schema: TSchema; const PackageName: string): string;
var
  QueryCode: string;
  i, j: Integer;
  SqlName, ParamsName, ResultName: string;
  ParamsFields, ResultFields: TStringArray;
  ResultFieldsStr: string;
begin
  Result := 'package ' + PackageName + #13#10#13#10;
  Result := Result + 'import (' + #13#10;
  Result := Result + '  "context"' + #13#10;
  Result := Result + ')' + #13#10;
  
  
  for i := 0 to Length(Queries) - 1 do
  begin
    Result := Result + #13#10#13#10 + '// ' + Queries[i].QueryToken.Name;
    
    // Генерация SQL-запроса
    SqlName := Queries[i].QueryToken.Name + 'Sql';
    Result := Result + #13#10 + 'const ' + SqlName + ' = `' + #13#10 + Queries[i].ResultSQL + #13#10 + '`';
    
    // Генерация структуры параметров
    ParamsName := Capitalize(Queries[i].QueryToken.Name) + 'Params';
    SetLength(ParamsFields, Length(Queries[i].Params));
    
    for j := 0 to Length(Queries[i].Params) - 1 do
    begin
      case Queries[i].Params[j].ParamType of
        otString: ParamsFields[j] := Capitalize(Queries[i].Params[j].Name) + ' string';
        otInteger: ParamsFields[j] := Capitalize(Queries[i].Params[j].Name) + ' int';
      end;
    end;
    
    Result := Result + #13#10 + 'type ' + ParamsName + ' struct {' + #13#10;
    for j := 0 to Length(ParamsFields) - 1 do
      Result := Result + '  ' + ParamsFields[j] + #13#10;
    Result := Result + '}';
    
    // Генерация структуры результата
    ResultName := Capitalize(Queries[i].QueryToken.Name) + 'Result';
    ResultFields := GetResultFields(Queries[i], Schema);
    
    Result := Result + #13#10 + 'type ' + ResultName + ' struct {' + #13#10;
    for j := 0 to Length(ResultFields) - 1 do
    begin
      // Поиск типа поля
      ResultFieldsStr := ResultFields[j] + ' ';
      
      // Упрощенная версия - предполагаем, что все поля имеют тип string
      ResultFieldsStr := ResultFieldsStr + 'string';
      
      Result := Result + '  ' + ResultFieldsStr + #13#10;
    end;
    Result := Result + '}';
    
    // Генерация функции запроса
    try
      case Queries[i].QueryToken.ReturnType of
        qrtOne:
          begin
            QueryCode := GenerateReturnOne(Queries[i], SqlName, ParamsName, ResultName, ResultFields);
          end;
        qrtMany:
          begin
            QueryCode := GenerateReturnMany(Queries[i], SqlName, ParamsName, ResultName, ResultFields);
          end;
        qrtExec:
          begin
            QueryCode := GenerateExec(Queries[i], SqlName, ParamsName, ResultName, ResultFields);
          end;
      end;
    except
      on E: Exception do
      begin
        raise; // Перевыбрасываем исключение после логирования
      end;
    end;
    
    Result := Result + QueryCode;
  end;
  
  GenerateQueryFile := Result;
end;

end.

