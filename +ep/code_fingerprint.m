function digest = code_fingerprint()
%CODE_FINGERPRINT Identify the exact MATLAB sources used by saved runs.
root=fileparts(fileparts(mfilename('fullpath')));
files=[dir(fullfile(root,'*.m'));dir(fullfile(root,'+ep','*.m'))];
names=cell(numel(files),1);
for j=1:numel(files)
    path=fullfile(files(j).folder,files(j).name);
    names{j}=path(numel(root)+2:end);
end
[~,order]=sort(names);
assert(usejava('jvm'),'EP:Java','Source provenance hashing requires the MATLAB JVM.');
md=javaMethod('getInstance','java.security.MessageDigest','SHA-256');
for j=order(:)'
    path=fullfile(files(j).folder,files(j).name);
    relative=strrep(names{j},filesep,'/');
    entry=[relative,char(0),ep.sha256_file(path),char(10)];
    md.update(typecast(uint8(unicode2native(entry,'UTF-8')),'int8'));
end
bytes=typecast(md.digest(),'uint8');
digest=lower(reshape(dec2hex(bytes,2).',1,[]));
end
