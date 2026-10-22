function atomic_save(path,payload)
%ATOMIC_SAVE Write a complete MAT file before replacing its destination.
folder=fileparts(path); if ~isfolder(folder), mkdir(folder); end
tmp=[tempname(folder),'.mat'];
cleanup=onCleanup(@()remove_if_present(tmp)); %#ok<NASGU>
save(tmp,'-struct','payload','-v7');
[ok,msg]=movefile(tmp,path,'f');
assert(ok,'EP:Save','Could not commit checkpoint: %s.',msg);
end

function remove_if_present(path)
if isfile(path), delete(path); end
end
