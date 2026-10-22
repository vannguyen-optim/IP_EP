function output_file = EP_DOWNLOAD_ACN(output_file)
%EP_DOWNLOAD_ACN Retrieve actual Caltech May 2019 records from the official API.
%   Put an access token in the ACN_API_TOKEN environment variable first.
%   Tokens are used only in the HTTPS request and are not saved or displayed.
cfg=EP_CONFIG('publication');
if nargin<1
    output_file=fullfile(fileparts(cfg.data_file),'acn_caltech_may2019_raw.json');
end
token=getenv('ACN_API_TOKEN');
assert(~isempty(token),'EP:ACNToken',...
    'Set ACN_API_TOKEN, or download JSON at https://ev.caltech.edu/dataset and use EP_IMPORT_ACN.');
endpoint='https://ev.caltech.edu/api/v1/sessions/caltech';
condition=['connectionTime>="Wed, 1 May 2019 07:00:00 GMT" and ',...
    'connectionTime<"Sat, 1 Jun 2019 07:00:00 GMT"'];
options=weboptions('Username',token,'Password','','ContentType','json','Timeout',60);
all_sessions={}; page=0; url=endpoint; expected_total=[]; visited={};
while true
    page=page+1;
    assert(page<=10000,'EP:Pagination','Too many API pages.');
    assert(~any(strcmp(visited,url)),'EP:Pagination','Repeated API pagination target.');
    visited{end+1}=url; %#ok<AGROW>
    if page==1
        payload=webread(url,'where',condition,options);
    else
        payload=webread(url,options);
    end
    assert(isstruct(payload) && isscalar(payload) && ...
        (isfield(payload,'_items') || isfield(payload,matlab.lang.makeValidName('_items'))),...
        'EP:API','API response is missing its session array.');
    items=ep.json_field(payload,'_items',{});
    if isempty(items), items={}; end
    if isstruct(items), items=num2cell(items); end
    assert(iscell(items),'EP:API','API response has no session array.');
    meta=ep.json_field(payload,'_meta',struct());
    total=ep.json_field(meta,'total',[]);
    if ischar(total) || isstring(total), total=str2double(total); end
    assert(isnumeric(total) && isscalar(total) && isfinite(total) && ...
        total>=0 && total==fix(total),'EP:API','API response lacks a valid total count.');
    if isempty(expected_total), expected_total=total; end
    assert(total==expected_total,'EP:PartialData','API total changed during pagination.');
    reported_page=ep.json_field(meta,'page',[]);
    if ischar(reported_page) || isstring(reported_page), reported_page=str2double(reported_page); end
    if ~isempty(reported_page)
        assert(isnumeric(reported_page) && isscalar(reported_page) && reported_page==page,...
            'EP:Pagination','API page sequence is incomplete or repeated.');
    end
    for j=1:numel(items)
        s=items{j};
        assert(isstruct(s) && isscalar(s),'EP:API','Invalid session object in API response.');
        record=struct('sessionID',ep.json_field(s,'sessionID',''),...
            'connectionTime',ep.json_field(s,'connectionTime',''),...
            'disconnectTime',ep.json_field(s,'disconnectTime',''),...
            'kWhDelivered',ep.json_field(s,'kWhDelivered',NaN),...
            'timezone',ep.json_field(s,'timezone','America/Los_Angeles'),...
            'siteID',ep.json_field(s,'siteID',''));
        all_sessions{end+1,1}=record; %#ok<AGROW>
    end
    links=ep.json_field(payload,'_links',struct());
    next=ep.json_field(links,'next',struct()); href=ep.json_field(next,'href','');
    fprintf('ACN page %d: %d sessions retained in the local download.\n',page,numel(all_sessions));
    assert(numel(all_sessions)<=expected_total,'EP:PartialData','Received more sessions than advertised.');
    if isempty(href), break; end
    assert(~isempty(items) && numel(all_sessions)<expected_total,...
        'EP:PartialData','Invalid next-page link or empty intermediate page.');
    if startsWith(href,'https://ev.caltech.edu/api/v1/')
        url=href;
    elseif startsWith(href,'/api/v1/')
        url=['https://ev.caltech.edu',href];
    elseif startsWith(href,'sessions/')
        url=['https://ev.caltech.edu/api/v1/',href];
    else
        error('EP:APIHost','Unexpected API pagination target.');
    end
end
assert(numel(all_sessions)==expected_total,'EP:PartialData',...
    'The API download is incomplete; no raw or prepared data have been replaced.');
clear token options;
provenance=struct('source_kind','ACN-Data','endpoint',endpoint,'query',condition,...
    'downloaded_utc',char(datetime('now','TimeZone','UTC')),'pages',page,...
    'site','caltech','advertised_sessions',expected_total,...
    'received_sessions',numel(all_sessions),'complete_export',true);
folder=fileparts(output_file); if isempty(folder), folder=pwd; end
if ~isfolder(folder), mkdir(folder); end
temporary=[tempname(folder),'.json'];
remove_temporary=onCleanup(@()remove_if_present(temporary)); %#ok<NASGU>
fid=fopen(temporary,'w','n','UTF-8'); assert(fid>=0,'EP:Write','Cannot write JSON.');
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
content=jsonencode(struct('sessions',{all_sessions},'provenance',provenance));
fprintf(fid,'%s',content);
assert(isempty(ferror(fid)),'EP:Write','Could not write the complete JSON download.');
clear c;
[ok,msg]=movefile(temporary,output_file,'f');
assert(ok,'EP:Write','Could not install the complete JSON download: %s.',msg);
EP_IMPORT_ACN(output_file);
end

function remove_if_present(path)
if isfile(path), delete(path); end
end
