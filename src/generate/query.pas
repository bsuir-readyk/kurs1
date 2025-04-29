unit query_gen;

interface

uses
  SysUtils, types, return_one, return_many, return_exec, logging;

// Функция для генерации кода запросов
function GenerateQueryFile(const Queries: array of TResolvedReturnQuery; const Schema: TSchema; const PackageName: string): string;

type TResultFields = record
  goFieldNames: array of string;
  goType: array of string;
end;

implementation

// Функция для преобразования первой буквы строки в верхний регистр
function Capitalize(const S: string): string;
begin
  if S = '' then
    Result := ''
  else
    Result := UpperCase(S[1]) + Copy(S, 2, Length(S) - 1);
end;

// Функция для получения полей результата запроса
function GetResultFields(const Query: TResolvedReturnQuery; const Schema: TSchema): TResultFields;
var
  ResultFields: TResultFields;
  i, j, k, m, FieldCount: Integer;
  TableName, FieldName: string;
  Found: Boolean;
  Log: TLogF;
begin
  Log := GetLogger(LL_NO_LOGS);

  ResultFields.goFieldNames := nil;
  ResultFields.goType := nil;
  FieldCount := 0;
  
  for i := 0 to Length(Query.Results) - 1 do
  begin
    TableName := Query.Results[i].TableName;
    
    for j := 0 to Length(Query.Results[i].Fields) - 1 do
    begin
      FieldName := Query.Results[i].Fields[j].TableField;
      if (Pos('.', FieldName)) <> 0 then
      begin
        FieldName := Copy(Query.Results[i].Fields[j].TableField, Pos('.', FieldName)+1, Length(Query.Results[i].Fields[j].TableField));
      end;
      
      if FieldName = '*' then
      begin
        // Если поле - звездочка, добавляем все поля таблицы
        for k := 0 to Length(Schema) - 1 do
        begin
          if Schema[k].Name = TableName then
          begin
            SetLength(ResultFields.goFieldNames, FieldCount + Length(Schema[k].Columns));
            SetLength(ResultFields.goType, FieldCount + Length(Schema[k].Columns));
            
            for m := 0 to Length(Schema[k].Columns) - 1 do
            begin
              ResultFields.goFieldNames[FieldCount] := Capitalize(Schema[k].Columns[m].Name);
              // log(LL_DEBUG, 'Schema[k].Columns[m].Name: ' + Schema[k].Columns[m].Name);
              // log(LL_DEBUG, 'Schema[k].Columns[m].ColumnType: ' + StringifyTColumnType(Schema[k].Columns[m].ColumnType));
              ResultFields.goType[FieldCount] := GoTypeToString(SqlToGoType(Schema[k].Columns[m].ColumnType));
              Inc(FieldCount);
            end;
            
            Break;
          end;
        end;
      end
      else
      begin
        // Если поле - конкретное имя, добавляем его
        SetLength(ResultFields.goFieldNames, FieldCount + 1);
        SetLength(ResultFields.goType, FieldCount + 1);

        ResultFields.goFieldNames[FieldCount] := Capitalize(Query.Results[i].Fields[j].ReturningName);
        
        log(LL_DEBUG, 'TableName: ' + TableName);
        log(LL_DEBUG, 'Query.Results[i].Fields[j].TableField: ' + Query.Results[i].Fields[j].TableField);
        log(LL_DEBUG, 'Query.Results[i].Fields[j].ReturningName: ' + Query.Results[i].Fields[j].ReturningName);

        for k := 0 to Length(Schema) - 1 do
        begin
          if Schema[k].Name = TableName then
          begin
            for m := 0 to Length(Schema[k].Columns) - 1 do
            begin
              if Schema[k].Columns[m].Name = Query.Results[i].Fields[j].TableField then
              begin
                ResultFields.goType[FieldCount] := GoTypeToString(SqlToGoType(Schema[k].Columns[m].ColumnType));
              end;
            end;
          end;
        end;

        Inc(FieldCount);
      end;
    end;
  end;
  
  log(LL_DEBUG, StringifyArr(ResultFields.goFieldNames));
  log(LL_DEBUG, StringifyArr(ResultFields.goType));
  log(LL_DEBUG, '----');
  // log(LL_DEBUG, StringifyInt(Length(ResultFields.goType)));
  // log(LL_DEBUG, StringifyInt(Length(ResultFields.goFieldNames)));
  Result := ResultFields;
end;

// Функция для генерации кода запросов
function GenerateQueryFile(const Queries: array of TResolvedReturnQuery; const Schema: TSchema; const PackageName: string): string;
var
  QueryCode, ResultFieldsStr: string;
  i, j: Integer;
  SqlName, ParamsName, ResultName: string;
  ParamsFieldsStrs, ResultFieldsStrs: TStringArray;
  ResultFields: TResultFields;
  log: TLogF;
begin
  log := GetLogger(LL_DEBUG);

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
    SetLength(ParamsFieldsStrs, Length(Queries[i].Params));
    
    for j := 0 to Length(Queries[i].Params) - 1 do
    begin
      case Queries[i].Params[j].ParamType of
        otString: ParamsFieldsStrs[j] := Capitalize(Queries[i].Params[j].Name) + ' string';
        otInteger: ParamsFieldsStrs[j] := Capitalize(Queries[i].Params[j].Name) + ' int';
      end;
    end;
    
    Result := Result + #13#10 + 'type ' + ParamsName + ' struct {' + #13#10;
    for j := 0 to Length(ParamsFieldsStrs) - 1 do begin
      Result := Result + '  ' + ParamsFieldsStrs[j] + #13#10;
    end;
    Result := Result + '}';
    
    // Генерация структуры результата
    ResultName := Capitalize(Queries[i].QueryToken.Name) + 'Result';
    ResultFields := GetResultFields(Queries[i], Schema);
    
    Result := Result + #13#10 + 'type ' + ResultName + ' struct {' + #13#10;
    // log(LL_DEBUG, StringifyArr(ResultFields));
    for j := 0 to Length(ResultFields.goType) - 1 do
    begin
      ResultFieldsStr := ResultFields.goFieldNames[j];
      ResultFieldsStr := ResultFieldsStr + ' ' + ResultFields.goType[j];
      Result := Result + '  ' + ResultFieldsStr + #13#10;
    end;
    Result := Result + '}';
    
    // Генерация функции запроса
    try
      case Queries[i].QueryToken.ReturnType of
        qrtOne:
          begin
            QueryCode := GenerateReturnOne(Queries[i], SqlName, ParamsName, ResultName, ResultFields.goFieldNames);
          end;
        qrtMany:
          begin
            QueryCode := GenerateReturnMany(Queries[i], SqlName, ParamsName, ResultName, ResultFields.goFieldNames);
          end;
        qrtExec:
          begin
            QueryCode := GenerateExec(Queries[i], SqlName, ParamsName, ResultName, ResultFields.goFieldNames);
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

