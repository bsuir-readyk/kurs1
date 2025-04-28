unit types;

interface

uses
  SysUtils;

type
  // Типы для конфигурации
  TPackage = record
    Name: string;
    Path: string;
  end;

  TConfig = record
    Schema: string;
    Queries: array of string;
    RemoveTrailingS: Boolean;
    Package: TPackage;
  end;

  // Типы для кодов
  TCodes = record
    Schema: string;
    Queries: array of string;
  end;

  // Типы для схемы
  TColumnType = (ctText, ctInteger);
  
  TColumn = record
    Name: string;
    ColumnType: TColumnType;
    Nullable: Boolean;
  end;
  
  TTableColumns = array of TColumn;
  
  TTable = record
    Name: string;
    Columns: TTableColumns;
  end;
  
  TSchema = array of TTable;

  // Типы для запросов
  TQueryReturnType = (qrtOne, qrtMany, qrtExec);
  
  TQueryToken = record
    SQL: string;
    Name: string;
    ReturnType: TQueryReturnType;
  end;
  
  TQueryTokenArray = array of TQueryToken;
  
  TOwnType = (otString, otInteger);
  
  TQueryParam = record
    Name: string;
    ParamType: TOwnType;
    Positions: array of Integer;
  end;
  
  TQueryParams = array of TQueryParam;
  
  TParamedQuery = record
    QueryToken: TQueryToken;
    Params: TQueryParams;
    ResultSQL: string;
  end;
  
  TParamedQueryArray = array of TParamedQuery;
  
  TReturningField = record
    TableField: string;
    ReturningName: string;
  end;
  
  TReturningFields = array of TReturningField;
  
  TTableResult = record
    TableName: string;
    Fields: TReturningFields;
  end;
  
  TTableResults = array of TTableResult;
  
  TResolvedReturnQuery = record
    QueryToken: TQueryToken;
    Params: TQueryParams;
    ResultSQL: string;
    Results: TTableResults;
  end;
  
  TResolvedReturnQueryArray = array of TResolvedReturnQuery;

  // Типы для генерации кода
  TGoType = (gtString, gtInt);

// Константы
const
  ALLOWED_QUERY_RETURN_TYPES: array[0..2] of string = ('one', 'many', 'exec');
  ALLOWED_SQL_COLUMN_TYPES: array[0..1] of string = ('TEXT', 'INTEGER');
  ALLOWED_GO_TYPES: array[0..1] of string = ('string', 'int');
  ALLOWED_OWN_TYPES: array[0..1] of string = ('string', 'int');

// Функции для проверки типов
function IsAllowedQueryReturnType(const TypeName: string): Boolean;
function IsAllowedSqlColumnType(const TypeName: string): Boolean;
function IsAllowedGoType(const TypeName: string): Boolean;
function IsAllowedOwnType(const TypeName: string): Boolean;

// Функции для преобразования типов
function SqlToJsType(const SqlType: TColumnType): string;
function SqlToGoType(const SqlType: TColumnType): TGoType;
function OwnToGoType(const OwnType: TOwnType): TGoType;
function GoTypeToString(const GoType: TGoType): string;

implementation

function IsAllowedQueryReturnType(const TypeName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(ALLOWED_QUERY_RETURN_TYPES) to High(ALLOWED_QUERY_RETURN_TYPES) do
    Result := (Result or (ALLOWED_QUERY_RETURN_TYPES[i] = TypeName));
end;

function IsAllowedSqlColumnType(const TypeName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(ALLOWED_SQL_COLUMN_TYPES) to High(ALLOWED_SQL_COLUMN_TYPES) do
    Result := (Result or (ALLOWED_SQL_COLUMN_TYPES[i] = TypeName));
end;

function IsAllowedGoType(const TypeName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(ALLOWED_GO_TYPES) to High(ALLOWED_GO_TYPES) do
    Result := (Result or (ALLOWED_GO_TYPES[i] = TypeName));
end;

function IsAllowedOwnType(const TypeName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Low(ALLOWED_OWN_TYPES) to High(ALLOWED_OWN_TYPES) do
    Result := (Result or (ALLOWED_OWN_TYPES[i] = TypeName));
end;

function SqlToJsType(const SqlType: TColumnType): string;
begin
  case SqlType of
    ctText: Result := 'string';
    ctInteger: Result := 'number';
  end;
end;

function SqlToGoType(const SqlType: TColumnType): TGoType;
begin
  case SqlType of
    ctText: Result := gtString;
    ctInteger: Result := gtInt;
  end;
end;

function OwnToGoType(const OwnType: TOwnType): TGoType;
begin
  case OwnType of
    otString: Result := gtString;
    otInteger: Result := gtInt;
  end;
end;

function GoTypeToString(const GoType: TGoType): string;
begin
  case GoType of
    gtString: Result := 'string';
    gtInt: Result := 'int';
  end;
end;

end.
