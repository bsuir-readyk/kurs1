unit schema_gen;

interface

uses
  SysUtils, types, fs;

// Функция для генерации кода схемы
function GenerateSchema(const Schema: TSchema; const PackageName: string; RemoveTrailingS: Boolean): string;

implementation

// Функция для преобразования первой буквы строки в верхний регистр
function Capitalize(const S: string): string;
begin
  if S = '' then
    Result := ''
  else
    Result := UpperCase(S[1]) + Copy(S, 2, Length(S) - 1);
end;

// Функция для генерации кода схемы
function GenerateSchema(const Schema: TSchema; const PackageName: string; RemoveTrailingS: Boolean): string;
var
  StructCode: string;
  i, j: Integer;
  TableName, StructName, GoType: string;
begin
  Result := 'package ' + PackageName + #13#10#13#10;
  Result := Result + 'import "database/sql"' + #13#10#13#10;
  Result := Result + 'type Queries struct {' + #13#10;
  Result := Result + '    DB *sql.DB' + #13#10;
  Result := Result + '}' + #13#10;
  
  for i := 0 to Length(Schema) - 1 do
  begin
    TableName := Schema[i].Name;
    StructName := Capitalize(TableName);
    
    if RemoveTrailingS and (Length(StructName) > 0) and (LowerCase(StructName[Length(StructName)]) = 's') then
      StructName := Copy(StructName, 1, Length(StructName) - 1);
    
    StructCode := #13#10 + 'type ' + StructName + ' struct {' + #13#10;
    
    for j := 0 to Length(Schema[i].Columns) - 1 do
    begin
      StructCode := StructCode + '    ' + Capitalize(Schema[i].Columns[j].Name) + ' ';
      
      case Schema[i].Columns[j].ColumnType of
        ctText: GoType := 'string';
        ctInteger: GoType := 'int';
      end;
      
      StructCode := StructCode + GoType + ' `db:"' + Schema[i].Columns[j].Name + '"`' + #13#10;
    end;
    
    StructCode := StructCode + '}' + #13#10;
    
    Result := Result + StructCode;
  end;
  
  GenerateSchema := Result;
end;

end.
