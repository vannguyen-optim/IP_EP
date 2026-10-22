function write_text(path,content)
%WRITE_TEXT Save UTF-8 text with literal TeX backslashes preserved.
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'EP:Write','Cannot write %s.',path);
c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',content);
end
