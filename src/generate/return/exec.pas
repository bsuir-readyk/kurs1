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
  CompleteGoParams, SqlVarName, PlaceholdersVarName: string;
  GoParams: array of string;
  i, j, k, ParamCount, ArrayParamCount: Integer;
  HasArrayParams: Boolean;
begin
  Result := '';
  HasArrayParams := False;
  ArrayParamCount := 0;
  
  // Check if we have any array parameters
  for i := 0 to Length(Query.Params) - 1 do
  begin
    if Query.Params[i].IsArray then
    begin
      HasArrayParams := True;
      Inc(ArrayParamCount);
    end;
  end;
  
  // Формирование параметров запроса
  ParamCount := 0;
  for i := 0 to Length(Query.Params) - 1 do
  begin
    // For array parameters, we'll handle them differently during query execution
    if not Query.Params[i].IsArray then
      ParamCount := ParamCount + Length(Query.Params[i].Positions);
  end;
  
  // Only allocate for non-array params, array params will be handled separately
  if not HasArrayParams then
  begin
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
  end;
  
  // Формирование функции
  if HasArrayParams then
  begin
    // Special handling for queries with array parameters
    SqlVarName := 'query';
    PlaceholdersVarName := 'placeholders';
    
    Result := #13#10 +
      'func (q *Queries) ' + Capitalize(Query.QueryToken.Name) + '(ctx context.Context, arg ' + ParamsName + ') error {' + #13#10;
    
    // Generate code to build dynamic SQL with the correct number of placeholders
    Result := Result + '  // Handle IN clause parameters' + #13#10;
    
    // For each array parameter, create placeholders
    for i := 0 to Length(Query.Params) - 1 do
    begin
      if Query.Params[i].IsArray then
      begin
        Result := Result + '  ' + PlaceholdersVarName + Capitalize(Query.Params[i].Name) + ' := make([]string, len(arg.' + Capitalize(Query.Params[i].Name) + '))' + #13#10;
        Result := Result + '  for i := range arg.' + Capitalize(Query.Params[i].Name) + ' {' + #13#10;
        Result := Result + '    ' + PlaceholdersVarName + Capitalize(Query.Params[i].Name) + '[i] = "?"' + #13#10;
        Result := Result + '  }' + #13#10;
      end;
    end;
    
    // Build the SQL query with substituted placeholders
    Result := Result + #13#10 + '  // Create SQL with correct number of placeholders' + #13#10;
    Result := Result + '  ' + SqlVarName + ' := ' + SqlName + #13#10;
    Result := Result + '  searchPos := 0' + #13#10;
    
    // For each array parameter, substitute placeholders
    for i := 0 to Length(Query.Params) - 1 do
    begin
      if Query.Params[i].IsArray then
      begin
        // For SQLite, we need to carefully find the correct '?' to replace.
        // We need to look for an exact "IN (?)" pattern, not just any "?".
        Result := Result + '  // Find the IN clause placeholder for: ' + Capitalize(Query.Params[i].Name) + #13#10;
        Result := Result + '  inClausePattern' + IntToStr(i) + ' := "IN (?"' + #13#10;
        Result := Result + '  inClauseIndex' + IntToStr(i) + ' := strings.Index(' + SqlVarName + '[searchPos:], inClausePattern' + IntToStr(i) + ')' + #13#10;
        Result := Result + '  if inClauseIndex' + IntToStr(i) + ' > 0 {' + #13#10;
        Result := Result + '    inClauseIndex' + IntToStr(i) + ' += searchPos' + #13#10;
        Result := Result + '    ' + SqlVarName + ' = ' + SqlVarName + '[:inClauseIndex' + IntToStr(i) + '+4] + strings.Join(' + PlaceholdersVarName + Capitalize(Query.Params[i].Name) + ', ",") + ' + SqlVarName + '[inClauseIndex' + IntToStr(i) + '+5:]' + #13#10;
        Result := Result + '    searchPos = inClauseIndex' + IntToStr(i) + ' + 6  // Move past this replacement' + #13#10;
        Result := Result + '  }' + #13#10;
      end;
    end;
    
    // Build params slice
    Result := Result + #13#10 + '  // Create parameters slice' + #13#10;
    Result := Result + '  params := make([]interface{}, 0)' + #13#10;
    
    // For simpler parameter handling, track all parameters by their positions
    Result := Result + '  // Track parameter positions' + #13#10;
    Result := Result + '  paramPositions := make(map[int]string)' + #13#10;
    
    // First, map all parameters to their positions
    for i := 0 to Length(Query.Params) - 1 do
    begin
      if not Query.Params[i].IsArray then
      begin
        for j := 0 to Length(Query.Params[i].Positions) - 1 do
        begin
          Result := Result + '  paramPositions[' + IntToStr(Query.Params[i].Positions[j]) + '] = "' + Query.Params[i].Name + '"' + #13#10;
        end;
      end
      else
      begin
        // For array parameters, just mark their position
        if Length(Query.Params[i].Positions) > 0 then
        begin
          Result := Result + '  paramPositions[' + IntToStr(Query.Params[i].Positions[0]) + '] = "' + Query.Params[i].Name + '_array"' + #13#10;
        end;
      end;
    end;
    
    // Now iterate through positions to add parameters in the correct order
    Result := Result + #13#10 + '  // Add parameters in correct order' + #13#10;
    Result := Result + '  maxPos := 0' + #13#10;
    Result := Result + '  for pos := range paramPositions {' + #13#10;
    Result := Result + '    if pos > maxPos {' + #13#10;
    Result := Result + '      maxPos = pos' + #13#10;
    Result := Result + '    }' + #13#10;
    Result := Result + '  }' + #13#10;
    Result := Result + '  for pos := 0; pos <= maxPos; pos++ {' + #13#10;
    Result := Result + '    paramName, exists := paramPositions[pos]' + #13#10;
    Result := Result + '    if !exists {' + #13#10;
    Result := Result + '      continue' + #13#10;
    Result := Result + '    }' + #13#10;
    
    // Handle regular parameters
    for i := 0 to Length(Query.Params) - 1 do
    begin
      if not Query.Params[i].IsArray then
      begin
        Result := Result + '    if paramName == "' + Query.Params[i].Name + '" {' + #13#10;
        Result := Result + '      params = append(params, arg.' + Capitalize(Query.Params[i].Name) + ')' + #13#10;
        Result := Result + '    }' + #13#10;
      end;
    end;
    
    // Handle array parameters
    for i := 0 to Length(Query.Params) - 1 do
    begin
      if Query.Params[i].IsArray then
      begin
        Result := Result + '    if paramName == "' + Query.Params[i].Name + '_array" {' + #13#10;
        Result := Result + '      for _, v := range arg.' + Capitalize(Query.Params[i].Name) + ' {' + #13#10;
        Result := Result + '        params = append(params, v)' + #13#10;
        Result := Result + '      }' + #13#10;
        Result := Result + '    }' + #13#10;
      end;
    end;
    
    Result := Result + '  }' + #13#10;
    
    // Execute the query
    Result := Result + #13#10 + '  // Execute the query with the dynamic SQL and parameters' + #13#10;
    Result := Result + '  _, err := q.DB.ExecContext(ctx, ' + SqlVarName + ', params...)' + #13#10;
    Result := Result + '  return err' + #13#10;
  end
  else
  begin
    // Standard query execution for non-array parameters
    Result := #13#10 +
      'func (q *Queries) ' + Capitalize(Query.QueryToken.Name) + '(ctx context.Context, arg ' + ParamsName + ') error {' + #13#10 +
      '  _, err := q.DB.ExecContext(ctx, ' + SqlName + ', ' + CompleteGoParams + ')' + #13#10 +
      '  return err' + #13#10;
  end;
  
  Result := Result + '}';
  
  GenerateExec := Result;
end;

end.
