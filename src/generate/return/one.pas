unit return_one;

interface

uses
  SysUtils, types, fs;

// Функция для генерации кода для запроса, возвращающего один результат
function GenerateReturnOne(const Query: TResolvedReturnQuery; const SqlName, ParamsName, ResultName: string; const ResultFields: array of string): string;

implementation

// Функция для преобразования первой буквы строки в верхний регистр
function Capitalize(const S: string): string;
begin
  if S = '' then
    Result := ''
  else
    Result := UpperCase(S[1]) + Copy(S, 2, Length(S) - 1);
end;

// Функция для генерации кода для запроса, возвращающего один результат
function GenerateReturnOne(const Query: TResolvedReturnQuery; const SqlName, ParamsName, ResultName: string; const ResultFields: array of string): string;
var
  CompleteGoParams, ScanFields: string;
  GoParams: array of string;
  i, j, ParamCount: Integer;
begin
  Result := '';
  
  // Формирование параметров запроса
  ParamCount := 0;
  for i := 0 to Length(Query.Params) - 1 do
    ParamCount := ParamCount + Length(Query.Params[i].Positions);
  
  SetLength(GoParams, ParamCount);
  
  for i := 0 to Length(Query.Params) - 1 do
    for j := 0 to Length(Query.Params[i].Positions) - 1 do
      GoParams[Query.Params[i].Positions[j]] := 'arg.' + Capitalize(Query.Params[i].Name);
  
  CompleteGoParams := '';
  for i := 0 to Length(GoParams) - 1 do
  begin
    if i > 0 then
      CompleteGoParams := CompleteGoParams + ', ';
    CompleteGoParams := CompleteGoParams + GoParams[i];
  end;
  
  // Формирование полей для сканирования
  ScanFields := '';
  for i := 0 to Length(ResultFields) - 1 do
  begin
    if i > 0 then
      ScanFields := ScanFields + ',' + #13#10 + '      ';
    ScanFields := ScanFields + '&i.' + ResultFields[i];
  end;
  
  // Формирование функции
  Result := #13#10 +
    'func (q *Queries) ' + Capitalize(Query.QueryToken.Name) + '(ctx context.Context, arg ' + ParamsName + ') (*' + ResultName + ', error) {' + #13#10 +
    '  row := q.DB.QueryRowContext(ctx, ' + SqlName + ', ' + CompleteGoParams + ')' + #13#10 +
    '  var i ' + ResultName + #13#10 +
    '  err := row.Scan(' + #13#10 +
    '    ' + ScanFields + #13#10 +
    '  )' + #13#10 +
    '  return &i, err' + #13#10 +
    '}';
  
  GenerateReturnOne := Result;
end;

end.
