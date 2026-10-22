function status = EP_STATUS(results_dir)
%EP_STATUS Count actual checkpoints against the stored experiment manifest.
if nargin<1, c=EP_CONFIG('publication'); results_dir=c.output_dir; end
s=load(fullfile(results_dir,'manifest.mat'),'manifest');
keys=s.manifest.expected_keys; complete=0; converged=0; capped=0; errors=0; stale=0;
for j=1:numel(keys)
    path=fullfile(results_dir,'checkpoints',[keys{j},'.mat']);
    if ~isfile(path), continue; end
    r=load(path,'result','signature');
    if ~isfield(r,'signature') || ~strcmp(r.signature,s.manifest.expected_signatures{j})
        stale=stale+1; continue;
    end
    complete=complete+1;
    switch r.result.status
        case 'converged', converged=converged+1;
        case 'iteration_cap', capped=capped+1;
        otherwise, errors=errors+1;
    end
end
status=struct('expected',numel(keys),'complete',complete,...
    'remaining',numel(keys)-complete,'converged',converged,'capped',capped,...
    'other_statuses',errors,'stale_checkpoints',stale,'data_status',s.manifest.data_status);
fprintf('Completed %d/%d; remaining %d; converged %d; capped %d; other %d.\n',...
    complete,numel(keys),numel(keys)-complete,converged,capped,errors);
fprintf('EV input status: %s\n',status.data_status);
if stale>0, fprintf('%d incompatible checkpoints will be recomputed on resume.\n',stale); end
end
