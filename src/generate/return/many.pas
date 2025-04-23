unit return_many;

interface

uses
  SysUtils, types, fs;

// Функция для генерации кода для запроса, возвращающего множество результатов
function GenerateReturnMany(const Query: TResolvedReturnQuery; const SqlName, ParamsName, ResultName: string; const ResultFields: array of string): string;

implementation

// Функция для преобразования первой буквы строки в верхний регистр
function Capitalize(const S: string): string;
begin
  if S = '' then
    Result := ''
  else
    Result := UpperCase(S[1]) + Copy(S, 2, Length(S) - 1);
end;

// Функция для генерации кода для запроса, возвращающего множество результатов
function GenerateReturnMany(const Query: TResolvedReturnQuery; const SqlName, ParamsName, ResultName: string; const ResultFields: array of string): string;
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
      ScanFields := ScanFields + ',' + #13#10 + '        ';
    ScanFields := ScanFields + '&i.' + ResultFields[i];
  end;
  
  // Формирование функции
  Result := #13#10 +
    'func (q *Queries) ' + Capitalize(Query.QueryToken.Name) + '(ctx context.Context, arg ' + ParamsName + ') (*[]' + ResultName + ', error) {' + #13#10 +
    '  rows, err := q.DB.QueryContext(ctx, ' + SqlName + ', ' + CompleteGoParams + ')' + #13#10 +
    '  if err != nil {' + #13#10 +
    '    return nil, err' + #13#10 +
    '  }' + #13#10 +
    '  defer rows.Close()' + #13#10 +
    '  var items []' + ResultName + #13#10 +
    '  for rows.Next() {' + #13#10 +
    '    var i ' + ResultName + #13#10 +
    '    if err := rows.Scan(' + #13#10 +
    '      ' + ScanFields + #13#10 +
    '    ); err != nil {' + #13#10 +
    '      return nil, err' + #13#10 +
    '    }' + #13#10 +
    '    items = append(items, i)' + #13#10 +
    '  }' + #13#10 +
    '  if err := rows.Close(); err != nil {' + #13#10 +
    '    return nil, err' + #13#10 +
    '  }' + #13#10 +
    '  if err := rows.Err(); err != nil {' + #13#10 +
    '    return nil, err' + #13#10 +
    '  }' + #13#10 +
    '  return &items, nil' + #13#10 +
    '}';
  
  GenerateReturnMany := Result;
end;

end.
