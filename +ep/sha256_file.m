function digest = sha256_file(path)
%SHA256_FILE Hash input data without recording authentication credentials.
assert(usejava('jvm'),'EP:Java','File provenance hashing requires the MATLAB JVM.');
md=javaMethod('getInstance','java.security.MessageDigest','SHA-256');
fid=fopen(path,'rb'); assert(fid>=0,'EP:Read','Cannot open the data file.');
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
while true
    bytes=fread(fid,1024*1024,'*uint8');
    if isempty(bytes), break; end
    md.update(typecast(bytes,'int8'));
end
bytes=typecast(md.digest(),'uint8');
digest=lower(reshape(dec2hex(bytes,2).',1,[]));
end
