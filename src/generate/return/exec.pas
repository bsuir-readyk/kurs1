unit return_exec;

interface

uses
  SysUtils, types;

// Функция для генерации кода для запроса, не возвращающего результатов
function GenerateExec(const Query: TResolvedReturnQuery; const SqlName, ParamsName, ResultName: string; const ResultFields: array of string): string;

implementation

// Функция для преобразования первой буквы строки в верхний регистр
function Capitalize(const S: string): string;
begin
  if S = '' then
    Result := ''
  else
    Result := UpperCase(S[1]) + Copy(S, 2, Length(S) - 1);
end;

// Функция для генерации кода для запроса, не возвращающего результатов
function GenerateExec(const Query: TResolvedReturnQuery; const SqlName, ParamsName, ResultName: string; const ResultFields: array of string): string;
var
  CompleteGoParams: string;
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
  
  // Формирование функции
  Result := #13#10 +
    'func (q *Queries) ' + Capitalize(Query.QueryToken.Name) + '(ctx context.Context, arg ' + ParamsName + ') error {' + #13#10 +
    '  _, err := q.DB.ExecContext(ctx, ' + SqlName + ', ' + CompleteGoParams + ')' + #13#10 +
    '  return err' + #13#10 +
    '}';
  
  GenerateExec := Result;
end;

end.
