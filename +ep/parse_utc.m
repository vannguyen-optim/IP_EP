function t = parse_utc(value)
%PARSE_UTC Parse official ACN RFC1123/GMT or explicit ISO8601 UTC timestamps.
if isdatetime(value)
    t=value;
    if isempty(t.TimeZone), t.TimeZone='UTC'; else, t.TimeZone='UTC'; end
    return;
end
s=strtrim(char(string(value)));
if endsWith(s,'GMT')
    s=regexprep(s,'^[A-Za-z]+,\s*','');
    s=regexprep(s,'\s*GMT$','');
    t=datetime(s,'InputFormat','d MMM yyyy HH:mm:ss','Locale','en_US','TimeZone','UTC');
    return;
end
formats={'yyyy-MM-dd''T''HH:mm:ss.SSSXXX','yyyy-MM-dd''T''HH:mm:ssXXX',...
    'yyyy-MM-dd HH:mm:ss.SSS','yyyy-MM-dd HH:mm:ss'};
for j=1:numel(formats)
    try
        t=datetime(s,'InputFormat',formats{j},'TimeZone','UTC');
        if ~isnat(t), return; end
    catch
    end
end
error('EP:Timestamp','Timestamp is not a supported UTC representation.');
end
