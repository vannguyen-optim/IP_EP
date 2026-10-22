function EP_COPY_TO_MANUSCRIPT(results_dir,manuscript_dir)
%EP_COPY_TO_MANUSCRIPT Copy completed publication tables/figures into the paper.
%   EP_COPY_TO_MANUSCRIPT('results_publication','../manuscript')
if nargin<1, c=EP_CONFIG('publication'); results_dir=c.output_dir; end
if nargin<2, manuscript_dir=fullfile(fileparts(mfilename('fullpath')),'..','manuscript'); end
if ~isfolder(manuscript_dir), mkdir(manuscript_dir); end
m=load(fullfile(results_dir,'manifest.mat'),'manifest'); cfg=m.manifest.cfg;
assert(strcmp(cfg.profile,'publication') && ~cfg.synthetic_ev_for_smoke,...
    'EP:ScientificExport','Only publication runs can be copied into the manuscript.');
s=EP_STATUS(results_dir);
assert(s.expected>0,'EP:NoRuns','No publication runs are scheduled in the current manifest.');
assert(s.remaining==0,'EP:Incomplete','Finish or resume all scheduled runs before copying.');
assert(s.other_statuses==0,'EP:Certificates','Resolve non-cap solver/certificate failures before copying.');
if any(strcmp(cfg.scopes,'ev'))
    assert(strcmp(s.data_status,'ACN-Data_imported'),...
        'EP:MissingEV','The requested real-EV experiment is incomplete. Import ACN data and resume before copying.');
    assert(isfield(m.manifest,'data_snapshot') && isfield(m.manifest.data_snapshot,'audit') && ...
        m.manifest.data_snapshot.audit.retained_days>0,...
        'EP:MissingEV','The saved experiment has no retained real charging days.');
end
[~,files]=EP_EXPORT(results_dir);
tracking=fullfile(manuscript_dir,'experiment_export_manifest.mat');
if isfile(tracking)
    old=load(tracking,'export_manifest');
    obsolete=setdiff(old.export_manifest.files,files);
    for j=1:numel(obsolete)
        parent=fileparts(obsolete{j});
        if ~ismember(parent,{'tables','figures'}), continue; end
        path=fullfile(manuscript_dir,obsolete{j});
        if isfile(path), delete(path); end
    end
end
for j=1:numel(files)
    target=fullfile(manuscript_dir,files{j}); folder=fileparts(target);
    if ~isfolder(folder), mkdir(folder); end
    [ok,msg]=copyfile(fullfile(results_dir,files{j}),target,'f');
    assert(ok,'EP:Copy','Copy failed: %s.',msg);
end
[ok,msg]=copyfile(fullfile(results_dir,'export_manifest.mat'),tracking,'f');
assert(ok,'EP:Copy','Could not save export provenance: %s.',msg);
fprintf('Publication tables and figures copied to %s.\n',manuscript_dir);
end
