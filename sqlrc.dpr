program sqlrc;

uses
  SysUtils,
  logging in 'src\logging.pas',
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
  Log: TLogF;
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

    Log := GetLogger(LL_INFO);

    ConfigPath := ExpandFileName(ParamStr(2));
    WorkDir := ExtractFileDir(ConfigPath);

    Log(LL_INFO, 'Started...');
    Config := GetConfig(ConfigPath);
    
    Log(LL_INFO, 'Getting code sources...');
    Codes := GetCodes(Config, WorkDir);
    
    Log(LL_INFO, 'Parsing schema...');
    SchemaTokens := ParseSchema(Codes.Schema);
    
    Log(LL_INFO, 'Generating schema content...');
    SchemaContent := GenerateSchema(SchemaTokens, Config.Package.Name, Config.RemoveTrailingS);
    
    SchemaPath := IncludeTrailingPathDelimiter(WorkDir) + Config.Package.Path + 'schema.go';
    
    Log(LL_INFO, 'Writing schema content...');
    Write(SchemaContent, SchemaPath);
    
    WriteLn('✅ Wrote schema to ' + SchemaPath);

    Log(LL_INFO, 'Parsing queries from source code...');
    QuerySetsTokens := ParseQueries(Codes.Queries);
  
    Log(LL_INFO, 'Parsing queries params...');
    QuerySetsWithParams := ParseQueryParams(QuerySetsTokens);
  
    Log(LL_INFO, 'Parsing queries results...');
    QuerySetsWithResolvedResult := ParseResolveResult(QuerySetsWithParams);
  
    Log(LL_INFO, 'Generating queries content...');
    QuerySetsContent := GenerateQueryFile(QuerySetsWithResolvedResult, SchemaTokens, Config.Package.Name);
  
    Log(LL_INFO, 'Writing queries content...');
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
