function [days,audit,provenance] = EP_IMPORT_ACN(input_file,output_file,cfg)
%EP_IMPORT_ACN Import real Caltech ACN JSON/CSV sessions, local May 2019.
%   EP_IMPORT_ACN uses the bundled source when cfg.acn_source_file exists.
%   EP_IMPORT_ACN('/absolute/path/caltech_sessions.json')
%   CSV columns: sessionID, connectionTime, disconnectTime, kWhDelivered.
%   Timestamps must be official GMT/RFC1123, ISO8601 with an offset, or UTC
%   yyyy-MM-dd HH:mm:ss. No measured charging trajectories are synthesized.
if nargin<3, cfg=EP_CONFIG('publication'); end
if nargin<2 || isempty(output_file), output_file=cfg.data_file; end
if nargin<1
    if isfield(cfg,'acn_source_file') && isfile(cfg.acn_source_file)
        input_file=cfg.acn_source_file;
    else
        [file,folder]=uigetfile({'*.json;*.csv','ACN session exports (*.json, *.csv)'},...
            'Select an actual ACN-Data export');
        assert(~isequal(file,0),'EP:DataFile','No input data file was selected.');
        input_file=fullfile(folder,file);
    end
end
assert(isfile(input_file),'EP:DataFile','Input data file does not exist.');
[~,~,ext]=fileparts(input_file);
upstream=struct();
switch lower(ext)
    case '.json'
        raw=jsondecode(fileread(input_file));
        upstream=ep.json_field(raw,'provenance',struct());
        if hasfield(raw,'_items')
            sessions=ep.json_field(raw,'_items',[]);
        elseif hasfield(raw,'sessions')
            sessions=ep.json_field(raw,'sessions',[]);
        else
            sessions=raw;
        end
        if isempty(sessions), sessions={}; end
        if isstruct(sessions), sessions=num2cell(sessions); end
        assert(iscell(sessions),'EP:JSON','Expected a session array or an _items object.');
        links=ep.json_field(raw,'_links',struct());
        next=ep.json_field(links,'next',[]);
        meta=ep.json_field(raw,'_meta',struct()); total=ep.json_field(meta,'total',[]);
        if ischar(total) || isstring(total), total=str2double(total); end
        truncated=~isempty(next) || (isnumeric(total) && isscalar(total) && ...
            isfinite(total) && total>numel(sessions));
        assert(~truncated,'EP:PartialData',...
            'This JSON is an incomplete API page. Use EP_DOWNLOAD_ACN or an official full-session export.');
    case '.csv'
        opts=detectImportOptions(input_file,'TextType','string','VariableNamingRule','preserve');
        opts=setvartype(opts,opts.VariableNames,'string');
        tab=readtable(input_file,opts);
        need={'sessionID','connectionTime','disconnectTime','kWhDelivered'};
        assert(all(ismember(need,tab.Properties.VariableNames)),...
            'EP:CSV','CSV must contain sessionID, connectionTime, disconnectTime, kWhDelivered.');
        sessions=num2cell(table2struct(tab));
    otherwise
        error('EP:Format','Provide an official JSON export or normalized CSV.');
end
n=numel(sessions); status=strings(n,1); ids=strings(n,1); datekey=strings(n,1);
energy=NaN(n,1); masks=false(n,cfg.ev.n_slots);
arrival=NaT(n,1,'TimeZone','UTC'); departure=arrival;
seen=containers.Map('KeyType','char','ValueType','logical');
first=datetime(cfg.ev.first_day,'InputFormat','yyyy-MM-dd','TimeZone',cfg.ev.timezone);
last=datetime(cfg.ev.end_day_exclusive,'InputFormat','yyyy-MM-dd','TimeZone',cfg.ev.timezone);
for k=1:n
    s=sessions{k};
    try
        id_text=string(ep.json_field(s,'sessionID',''));
        if isempty(id_text) || (isscalar(id_text) && ~ismissing(id_text) && strlength(strtrim(id_text))==0)
            id_text=string(ep.json_field(s,'_id',''));
        end
        assert(isscalar(id_text) && ~ismissing(id_text));
        id=char(strtrim(id_text));
        assert(~isempty(id)); ids(k)=string(id);
        if isKey(seen,id), status(k)="duplicate"; continue; end
        a=ep.parse_utc(ep.json_field(s,'connectionTime',''));
        b=ep.parse_utc(ep.json_field(s,'disconnectTime',''));
        e=ep.json_field(s,'kWhDelivered',NaN);
        if ischar(e) || isstring(e), e=str2double(e); end
        assert(isscalar(e) && isfinite(e) && e>0 && ~isnat(a) && ~isnat(b) && b>a);
        % Keep the first occurrence with valid times and positive energy.
        % A malformed record must not suppress a later valid copy of its ID.
        seen(id)=true;
        arrival(k)=a; departure(k)=b; energy(k)=e;
        a.TimeZone=cfg.ev.timezone; b.TimeZone=cfg.ev.timezone;
        if a<first || a>=last, status(k)="outside_month"; continue; end
        day=dateshift(a,'start','day');
        if day~=dateshift(b,'start','day'), status(k)="different_local_day"; continue; end
        day.Format='yyyy-MM-dd'; datekey(k)=string(day);
        left=ceil(seconds(a-day)/(3600*cfg.ev.dt_hours))+1;
        right=floor(seconds(b-day)/(3600*cfg.ev.dt_hours));
        left=max(1,left); right=min(cfg.ev.n_slots,right);
        if left>right, status(k)="empty_window"; continue; end
        mask=false(1,cfg.ev.n_slots); mask(left:right)=true;
        capacity=cfg.ev.dt_hours*cfg.ev.power_cap_kw*nnz(mask);
        if e>capacity, status(k)="energy_infeasible"; continue; end
        masks(k,:)=mask; status(k)="retained";
    catch
        status(k)="invalid_record";
    end
end
keep=find(status=="retained");
unique_days=unique(datekey(keep),'sorted'); days=cell(numel(unique_days),1);
for j=1:numel(unique_days)
    kk=keep(datekey(keep)==unique_days(j));
    % Stable, explicit session ordering makes downstream matrices reproducible.
    [~,order]=sort(ids(kk)); kk=kk(order);
    days{j}=struct('date',char(unique_days(j)),'mask',masks(kk,:),'energy',energy(kk),...
        'session_ids',{cellstr(ids(kk))},'source_kind','ACN-Data');
end
audit=struct('raw_sessions',n,'distinct_session_ids',numel(unique(ids(strlength(ids)>0))),...
    'duplicates',nnz(status=="duplicate"),...
    'invalid_records',nnz(status=="invalid_record"),'outside_month',nnz(status=="outside_month"),...
    'different_local_day',nnz(status=="different_local_day"),...
    'valid_same_day',nnz(ismember(status,["empty_window","energy_infeasible","retained"])),...
    'empty_window',nnz(status=="empty_window"),'energy_infeasible',nnz(status=="energy_infeasible"),...
    'retained_sessions',numel(keep),'retained_days',numel(days));
assert(sum([audit.duplicates,audit.invalid_records,audit.outside_month,...
    audit.different_local_day,audit.empty_window,audit.energy_infeasible,audit.retained_sessions])==n);
info=dir(input_file);
provenance=struct('source_kind','ACN-Data','source_file',char(input_file),...
    'sha256',ep.sha256_file(input_file),'source_bytes',info.bytes,...
    'imported_utc',char(datetime('now','TimeZone','UTC')),'site','caltech',...
    'documentation_url','https://ev.caltech.edu/dataset',...
    'preprocessing',cfg.ev,'code_version',cfg.code_version,...
    'upstream',upstream,...
    'deduplication','First occurrence with valid ordered timestamps and finite positive energy');
session_audit=table(ids,status,arrival,departure,energy,datekey,...
    'VariableNames',{'sessionID','status','connectionTimeUTC','disconnectTimeUTC','kWhDelivered','localDate'});
ep.atomic_save(output_file,struct('days',{days},'audit',audit,...
    'provenance',provenance,'session_audit',session_audit));
[folder,name]=fileparts(output_file);
writetable(session_audit,fullfile(folder,[name,'_session_audit.csv']));
writetable(struct2table(audit),fullfile(folder,[name,'_counts.csv']));
fprintf('Imported %d retained sessions on %d local days.\n',audit.retained_sessions,audit.retained_days);
fprintf('Prepared data: %s\n',output_file);
end

function tf=hasfield(s,name)
tf=isstruct(s) && isscalar(s) && ...
    (isfield(s,name) || isfield(s,matlab.lang.makeValidName(name)));
end
