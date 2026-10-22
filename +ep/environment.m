function env = environment()
%ENVIRONMENT Read the actual MATLAB and host details outside timed runs.
env=struct('matlab_release',version('-release'),'matlab_version',version,...
    'computer',computer,'cpu','','physical_cores',NaN,'ram_gib',NaN,'os','');
try
    if ismac
        [ok,txt]=system('sysctl -n machdep.cpu.brand_string');
        if ok==0, env.cpu=strtrim(txt); end
        [ok,txt]=system('sysctl -n hw.physicalcpu');
        if ok==0, env.physical_cores=str2double(strtrim(txt)); end
        [ok,txt]=system('sysctl -n hw.memsize');
        if ok==0, env.ram_gib=str2double(strtrim(txt))/2^30; end
        [ok,txt]=system('sw_vers -productVersion');
        if ok==0, env.os=['macOS ' strtrim(txt)]; end
    elseif isunix
        if isfile('/proc/cpuinfo')
            tok=regexp(fileread('/proc/cpuinfo'),'model name\s*:\s*([^\n]+)','tokens','once');
            if ~isempty(tok), env.cpu=strtrim(tok{1}); end
        end
        if isfile('/proc/meminfo')
            tok=regexp(fileread('/proc/meminfo'),'MemTotal:\s*(\d+)','tokens','once');
            if ~isempty(tok), env.ram_gib=str2double(tok{1})/2^20; end
        end
        [ok,txt]=system('uname -sr');
        if ok==0, env.os=strtrim(txt); end
    elseif ispc
        env.cpu=getenv('PROCESSOR_IDENTIFIER'); env.os='Windows';
        [~,mem]=memory;
        env.ram_gib=mem.PhysicalMemory.Total/2^30;
    end
catch
    % Unknown metadata stays empty; it does not change numerical outcomes.
end
end
