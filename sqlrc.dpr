program sqlrc;

uses
  SysUtils,
  types in 'src\types.pas',
  fs in 'src\fs.pas',
  schema in 'src\parse\schema.pas',
  query_parse in 'src\parse\query\parse.pas',
  query_params in 'src\parse\query\params.pas',
  query_result in 'src\parse\query\result.pas',
  schema_gen in 'src\generate\schema.pas',
  query_gen in 'src\generate\query.pas',
  return_one in 'src\generate\return\one.pas',
  return_many in 'src\generate\return\many.pas',
  return_exec in 'src\generate\return\exec.pas';

var
  ConfigPath: string;
  WorkDir: string;
  Config: TConfig;
  Codes: TCodes;
  SchemaTokens: TSchema;
  SchemaContent: string;
  SchemaPath: string;
  QuerySetsTokens: TQueryTokenArray;
  QuerySetsWithParams: TParamedQueryArray;
  QuerySetsWithResolvedResult: TResolvedReturnQueryArray;
  QuerySetsContent: string;
  QueryPath: string;
begin
  try
    WriteLn('sqlRc');
    WriteLn('CLI tool that uses SQL to create Golang structs and queries');
    WriteLn('--cfg <string>', 'Path to config');

    if (ParamCount < 2) or (ParamStr(1) <> '--cfg') then
    begin
      WriteLn('Usage: sqlrc --cfg <config_path>');
      Exit;
    end;

    ConfigPath := ExpandFileName(ParamStr(2));
    WorkDir := ExtractFileDir(ConfigPath);

    WriteLn('Started...');
    Config := GetConfig(ConfigPath);
    
    Codes := GetCodes(Config, WorkDir);
    
    SchemaTokens := ParseSchema(Codes.Schema);
    
    SchemaContent := GenerateSchema(SchemaTokens, Config.Package.Name, Config.RemoveTrailingS);
    
    SchemaPath := IncludeTrailingPathDelimiter(WorkDir) + Config.Package.Path + 'schema.go';
    
    Write(SchemaContent, SchemaPath);
    WriteLn('✅ Wrote schema to ' + SchemaPath);

    QuerySetsTokens := ParseQueries(Codes.Queries);
  
    QuerySetsWithParams := ParseQueryParams(QuerySetsTokens);
  
    QuerySetsWithResolvedResult := ParseResolveResult(QuerySetsWithParams);
  
    QuerySetsContent := GenerateQueryFile(QuerySetsWithResolvedResult, SchemaTokens, Config.Package.Name);
  
    QueryPath := IncludeTrailingPathDelimiter(WorkDir) + Config.Package.Path + 'query.go';

    Write(QuerySetsContent, QueryPath);
    WriteLn('✅ Wrote query to ' + QueryPath);
    except on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
