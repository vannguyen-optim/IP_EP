function [summary,exported_files] = EP_EXPORT(results_dir)
%EP_EXPORT Rebuild current paper outputs from compatible MATLAB checkpoints.
if nargin<1, c=EP_CONFIG('publication'); results_dir=c.output_dir; end
[runs,records,manifest]=ep.load_results(results_dir);
exported_files={};
if isempty(runs)
    summary=table(); fprintf('No completed MATLAB checkpoints to export.\n'); return;
end
assert(isfield(manifest.methods,'main') && isfield(manifest.methods,'kind'),...
    'EP:ProtocolVersion','This results folder uses an earlier protocol. Run the current package before exporting.');
hasEV=any(runs.model_type=="ev");
if hasEV && ~manifest.cfg.synthetic_ev_for_smoke
    assert(isfield(manifest,'data_snapshot') && isfield(manifest.data_snapshot,'audit') && ...
        isfield(manifest.data_snapshot,'provenance'),...
        'EP:DataSnapshot','The results lack frozen ACN provenance. Run the current package before exporting.');
end
folder=fullfile(results_dir,'tables'); if ~isfolder(folder), mkdir(folder); end
writetable(runs,fullfile(results_dir,'all_runs.csv'));
summary=ep.summarize(runs,manifest); writetable(summary,fullfile(results_dir,'summary.csv'));
ep.write_text(fullfile(results_dir,'protocol.json'),jsonencode(manifest));
[pairs,pair_summary]=ep.paired_speedups(runs,manifest);
write_or_remove(pairs,fullfile(results_dir,'paired_speedup_details.csv'));
write_or_remove(pair_summary,fullfile(results_dir,'paired_speedups.csv'));
if hasEV
    writetable(runs(runs.model_type=="ev",:),fullfile(results_dir,'ev_daily_results.csv'));
else
    remove_if_present(fullfile(results_dir,'ev_daily_results.csv'));
end
if hasEV && ~manifest.cfg.synthetic_ev_for_smoke
    % Export the input evidence frozen when these checkpoints were scheduled.
    snapshot=manifest.data_snapshot;
    writetable(struct2table(snapshot.audit),fullfile(results_dir,'ev_data_selection.csv'));
    ep.write_text(fullfile(results_dir,'ev_data_provenance.json'),jsonencode(snapshot.provenance));
else
    remove_if_present(fullfile(results_dir,'ev_data_selection.csv'));
    remove_if_present(fullfile(results_dir,'ev_data_provenance.json'));
end
if manifest.cfg.export_tables
    ep.export_tables(summary,pair_summary,records,manifest,folder);
end
if manifest.cfg.export_figures
    ep.export_figures(records,manifest,results_dir);
end
exported_files=ep.current_exports(summary,pair_summary,records,manifest);
exported_files=exported_files(cellfun(@(f)isfile(fullfile(results_dir,f)),exported_files));
tracking=fullfile(results_dir,'export_manifest.mat');
if isfile(tracking)
    old=load(tracking,'export_manifest');
    if isfield(old,'export_manifest') && isfield(old.export_manifest,'files')
        obsolete=setdiff(old.export_manifest.files,exported_files);
        for j=1:numel(obsolete)
            if ismember(fileparts(obsolete{j}),{'tables','figures'})
                remove_if_present(fullfile(results_dir,obsolete{j}));
            end
        end
    end
end
export_manifest=struct('files',{exported_files},...
    'expected_signatures',{manifest.expected_signatures},...
    'generated_utc',char(datetime('now','TimeZone','UTC')));
if isfield(manifest,'source_fingerprint'), export_manifest.source_fingerprint=manifest.source_fingerprint; end
ep.atomic_save(tracking,struct('export_manifest',export_manifest));
fprintf('Exported %d recorded runs to %s.\n',height(runs),results_dir);
end
function write_or_remove(t,path)
if isempty(t), remove_if_present(path); else, writetable(t,path); end
end
function remove_if_present(path)
if isfile(path), delete(path); end
end
