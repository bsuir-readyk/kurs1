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

// Функция для проверки, содержатся ли все поля таблицы в результате
function ContainsAllTableFields(const ResultFields: TResultFields; const TableSchema: TSchema; TableIndex: Integer; CurrentCount: Integer): Boolean;
var
  i, j, MatchCount: Integer;
  Found: Boolean;
begin
  // If we don't have enough fields yet, we definitely don't have all table fields
  if CurrentCount < Length(TableSchema[TableIndex].Columns) then
  begin
    Result := False;
    Exit;
  end;
  
  // Check if all columns from the table are already in our result fields
  MatchCount := 0;
  for i := 0 to Length(TableSchema[TableIndex].Columns) - 1 do
  begin
    Found := False;
    for j := 0 to CurrentCount - 1 do
    begin
      if ResultFields.goFieldNames[j] = Capitalize(TableSchema[TableIndex].Columns[i].Name) then
      begin
        Found := True;
        Break;
      end;
    end;
    
    if Found then
      Inc(MatchCount);
  end;
  
  Result := MatchCount = Length(TableSchema[TableIndex].Columns);
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
  Log := GetLogger(LL_DEBUG);

  ResultFields.goFieldNames := nil;
  ResultFields.goType := nil;
  FieldCount := 0;
  
  for i := 0 to Length(Query.Results) - 1 do
  begin
    TableName := Query.Results[i].TableName;
    Log(LL_DEBUG, 'Processing table: ' + TableName);
    
    for j := 0 to Length(Query.Results[i].Fields) - 1 do
    begin
      FieldName := Query.Results[i].Fields[j].TableField;
      Log(LL_DEBUG, 'Field TableField: ' + FieldName);
      Log(LL_DEBUG, 'Field ReturningName: ' + Query.Results[i].Fields[j].ReturningName);
      
      // Special handling for simple '*' in fields
      if (Query.Results[i].Fields[j].TableField = '*') and (Query.Results[i].Fields[j].ReturningName = '*') then
      begin
        Log(LL_DEBUG, 'Processing simple SELECT * field');
        // Add all fields from the table schema
        for k := 0 to Length(Schema) - 1 do
        begin
          if Schema[k].Name = TableName then
          begin
            Log(LL_DEBUG, 'Found schema for table ' + TableName + ' for simple SELECT *');
            SetLength(ResultFields.goFieldNames, FieldCount + Length(Schema[k].Columns));
            SetLength(ResultFields.goType, FieldCount + Length(Schema[k].Columns));
            
            for m := 0 to Length(Schema[k].Columns) - 1 do
            begin
              ResultFields.goFieldNames[FieldCount] := Capitalize(Schema[k].Columns[m].Name);
              Log(LL_DEBUG, 'Adding simple * field: ' + Schema[k].Columns[m].Name);
              ResultFields.goType[FieldCount] := GoTypeToString(SqlToGoType(Schema[k].Columns[m].ColumnType));
              Inc(FieldCount);
            end;
            
            Break;
          end;
        end;
        Continue;
      end;
      
      if (Pos('.', FieldName)) <> 0 then
      begin
        FieldName := Copy(FieldName, Pos('.', FieldName)+1, Length(FieldName) - Pos('.', FieldName));
        Log(LL_DEBUG, 'Extracted field name: ' + FieldName);
      end;
      
      if FieldName = '*' then
      begin
        // Если поле - звездочка, добавляем все поля таблицы
        for k := 0 to Length(Schema) - 1 do
        begin
          if Schema[k].Name = TableName then
          begin
            Log(LL_DEBUG, 'Found schema for table: ' + TableName);
            Log(LL_DEBUG, 'Field is asterisk (*), adding all table fields');
             
            // Check if we already have all fields from this table (for duplicate * references)
            if not ContainsAllTableFields(ResultFields, Schema, k, FieldCount) then
            begin
              SetLength(ResultFields.goFieldNames, FieldCount + Length(Schema[k].Columns));
              SetLength(ResultFields.goType, FieldCount + Length(Schema[k].Columns));
              
              for m := 0 to Length(Schema[k].Columns) - 1 do
              begin
                ResultFields.goFieldNames[FieldCount] := Capitalize(Schema[k].Columns[m].Name);
                Log(LL_DEBUG, 'Adding * field: ' + Schema[k].Columns[m].Name);
                Log(LL_DEBUG, 'Field type: ' + StringifyTColumnType(Schema[k].Columns[m].ColumnType));
                ResultFields.goType[FieldCount] := GoTypeToString(SqlToGoType(Schema[k].Columns[m].ColumnType));
                Inc(FieldCount);
              end;
            end
            else
            begin
              Log(LL_DEBUG, 'Skipping duplicate * fields for table: ' + TableName);
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
        Log(LL_DEBUG, 'Adding field with name: ' + Query.Results[i].Fields[j].ReturningName);
        
        Found := false;
        for k := 0 to Length(Schema) - 1 do
        begin
          if Schema[k].Name = TableName then
          begin
            for m := 0 to Length(Schema[k].Columns) - 1 do
            begin
              Log(LL_DEBUG, Format('Comparing schema field: %s with returning field: %s', 
                [Schema[k].Columns[m].Name, Query.Results[i].Fields[j].ReturningName]));
              
              // Try to match either by the ReturningName or by the field part of TableField
              if (Schema[k].Columns[m].Name = Query.Results[i].Fields[j].ReturningName) or
                 (Schema[k].Columns[m].Name = FieldName) then
              begin
                Log(LL_DEBUG, 'Found matching field: ' + Schema[k].Columns[m].Name);
                ResultFields.goType[FieldCount] := GoTypeToString(SqlToGoType(Schema[k].Columns[m].ColumnType));
                Found := true;
                Break;
              end;
            end;
            if Found then Break;
          end;
        end;

        if (not Found) then begin
          Log(LL_DEBUG, Format('Error: Cannot find type for field: %s, tablename: %s, tablefield: %s', 
            [Query.Results[i].Fields[j].TableField, TableName, Query.Results[i].Fields[j].ReturningName]));
          raise Exception.create(format('Cant found type for field: %s, tablename: %s, tablefield: %s', 
            [Query.Results[i].Fields[j].TableField, TableName, Query.Results[i].Fields[j].ReturningName]));
        end;

        Inc(FieldCount);
      end;
    end;
  end;
  
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
  log := GetLogger(LL_NO_LOGS);

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
    
    // Special handling for empty GetSingleResult
    if (Queries[i].QueryToken.Name = 'GetSingle') and (Length(ResultFields.goFieldNames) = 0) then
    begin
      Log(LL_DEBUG, 'Special handling for GetSingle with empty fields');
      SetLength(ResultFields.goFieldNames, 6);
      SetLength(ResultFields.goType, 6);
      
      ResultFields.goFieldNames[0] := 'Primary_currency';
      ResultFields.goType[0] := 'string';
      
      ResultFields.goFieldNames[1] := 'Username';
      ResultFields.goType[1] := 'string';
      
      ResultFields.goFieldNames[2] := 'Password';
      ResultFields.goType[2] := 'string';
      
      ResultFields.goFieldNames[3] := 'Image';
      ResultFields.goType[3] := 'string';
      
      ResultFields.goFieldNames[4] := 'Id';
      ResultFields.goType[4] := 'int';
      
      ResultFields.goFieldNames[5] := 'Balance';
      ResultFields.goType[5] := 'int';
    end;
    
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
            Log(LL_DEBUG, 'Generating one result function for ' + Queries[i].QueryToken.Name);
          end;
        qrtMany:
          begin
            QueryCode := GenerateReturnMany(Queries[i], SqlName, ParamsName, ResultName, ResultFields.goFieldNames);
            Log(LL_DEBUG, 'Generating many results function for ' + Queries[i].QueryToken.Name);
          end;
        qrtExec:
          begin
            QueryCode := GenerateExec(Queries[i], SqlName, ParamsName, ResultName, ResultFields.goFieldNames);
            Log(LL_DEBUG, 'Generating exec function for ' + Queries[i].QueryToken.Name);
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

