function export_figures(records,manifest,results_dir)
%EXPORT_FIGURES Publication residuals, conditioning panels, and charging plots.
folder=fullfile(results_dir,'figures'); if ~isfolder(folder), mkdir(folder); end
if isempty(records), return; end
methods=manifest.methods([manifest.methods.main]);
colors=lines(max(7,numel(methods))); % Safe for any supported method count.
ids=string(manifest.model_ids);
nonlinear=ids(startsWith(ids,'nonlinear_'));
dimensions=[];
for j=1:numel(nonlinear)
    t=regexp(char(nonlinear(j)),'^nonlinear_(\d+)_k\d+$','tokens','once');
    if ~isempty(t), dimensions(end+1)=str2double(t{1}); end %#ok<AGROW>
end
for n=unique(dimensions,'stable')
    kappas=manifest.cfg.nonlinear_conditioning(:)';
    fig=newfigure(manifest,numel(kappas));
    layout=tiledlayout(fig,1,numel(kappas),'TileSpacing','compact','Padding','compact');
    for j=1:numel(kappas)
        ax=nexttile(layout); id=sprintf('nonlinear_%d_k%d',n,kappas(j));
        group=select(records,id,'');
        draw_convergence(ax,group,methods,manifest.cfg.tolerance,colors);
        title(ax,sprintf('n = %d, \\kappa = %d',n,kappas(j)));
    end
    savefigure(fig,folder,sprintf('nonlinear_%d_convergence',n)); close(fig);
end
for id={'electricity','quadratic','river'}
    group=select(records,id{1},''); if isempty(group), continue; end
    fig=newfigure(manifest,1); ax=axes(fig);
    draw_convergence(ax,group,methods,manifest.cfg.tolerance,colors);
    title(ax,group{1}.meta.model_name,'Interpreter','none');
    savefigure(fig,folder,[id{1} '_convergence']); close(fig);
end
ev=records(cellfun(@(r)strcmp(r.meta.model_type,'ev'),records));
if ~isempty(ev)
    fig=newfigure(manifest,1); ax=axes(fig);
    draw_convergence(ax,ev,methods,manifest.cfg.tolerance,colors);
    title(ax,'Charging instances'); savefigure(fig,folder,'ev_convergence'); close(fig);
    daily(ev,manifest,methods,folder,colors);
    loadprofile(ev,manifest,methods,folder,colors);
end
end

function draw_convergence(ax,records,methods,tolerance,colors)
hold(ax,'on'); styleaxes(ax); set(ax,'YScale','log');
lim=0;
for j=1:numel(records)
    if isfield(records{j}.result,'history') && ~isempty(records{j}.result.history)
        lim=max(lim,records{j}.result.history(end,1));
    end
end
grid=unique(round(linspace(0,max(1,lim),min(1001,max(2,lim+1)))));
handles=gobjects(0); names={};
for m=1:numel(methods)
    data=select(records,'',methods(m).key); if isempty(data), continue; end
    curves=NaN(numel(data),numel(grid));
    for j=1:numel(data)
        if ~isfield(data{j}.result,'history') || isempty(data{j}.result.history), continue; end
        h=data{j}.result.history; xp=h(:,1); yp=h(:,2);
        % Missing or nonfinite histories are retained in the pointwise sample.
        valid=isfinite(yp); yp(valid)=max(yp(valid),realmin);
        [xp,ix]=unique(xp,'last'); yp=yp(ix);
        if numel(xp)==1
            curves(j,:)=yp(1);
        else
            curves(j,:)=interp1(xp,yp,grid,'previous',NaN);
            curves(j,grid>xp(end))=yp(end);
            curves(j,grid<xp(1))=yp(1);
        end
    end
    q=NaN(3,numel(grid));
    for j=1:numel(grid), q(:,j)=ep.percentile(curves(:,j),[.25 .5 .75])'; end
    [color,style]=method_style(methods(m),colors(m,:));
    fill(ax,[grid fliplr(grid)],[q(1,:) fliplr(q(3,:))],color,...
        'FaceAlpha',.10,'EdgeColor','none','HandleVisibility','off');
    handles(end+1)=plot(ax,grid,q(2,:),'Color',color,'LineStyle',style,'LineWidth',1.6); %#ok<AGROW>
    names{end+1}=methods(m).name; %#ok<AGROW>
end
yline(ax,tolerance,':','Tolerance','LabelHorizontalAlignment','left',...
    'HandleVisibility','off','Color',[.2 .2 .2]);
xlim(ax,[0 max(1,lim)]); xlabel(ax,'Updates'); ylabel(ax,'Normalized residual R_\eta');
if ~isempty(handles)
    legend(ax,handles,names,'Location','southoutside','NumColumns',3,...
        'Box','off','Interpreter','none','FontSize',9);
end
end

function daily(records,manifest,methods,folder,colors)
dates=cellfun(@(r)r.meta.date,records,'UniformOutput',false);
dates=sort(unique(dates));
fig=newfigure(manifest,2); layout=tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
for panel=1:2
    ax=nexttile(layout); hold(ax,'on'); styleaxes(ax);
    handles=gobjects(0); names={};
    for m=1:numel(methods)
        yy=NaN(1,numel(dates));
        for j=1:numel(dates)
            data=records(cellfun(@(r)strcmp(r.meta.date,dates{j}) && ...
                strcmp(r.meta.method_key,methods(m).key),records));
            values=NaN(numel(data),1);
            for k=1:numel(data)
                if panel==1, field='iterations'; else, field='time_seconds'; end
                if isfield(data{k}.result,field), values(k)=data{k}.result.(field); end
            end
            yy(j)=ep.percentile(values,.5);
        end
        [color,style]=method_style(methods(m),colors(m,:));
        handles(end+1)=plot(ax,1:numel(dates),yy,'Color',color,'LineStyle',style,...
            'Marker','.','MarkerSize',8,'LineWidth',1.4); %#ok<AGROW>
        names{end+1}=methods(m).name; %#ok<AGROW>
    end
    ticks=unique([1:5:numel(dates),numel(dates)]);
    ticklabels=cellfun(@(s)s(9:10),dates(ticks),'UniformOutput',false);
    set(ax,'XTick',ticks,'XTickLabel',ticklabels);
    xlim(ax,[.5 numel(dates)+.5]); xlabel(ax,'Local day in May 2019');
    if panel==1, ylabel(ax,'Updates'); else, ylabel(ax,'Elapsed time (s)'); end
    legend(ax,handles,names,'Location','southoutside','NumColumns',3,...
        'Interpreter','none','Box','off','FontSize',9);
end
savefigure(fig,folder,'ev_daily_comparison'); close(fig);
end

function loadprofile(records,manifest,methods,folder,colors)
% Select from all scheduled-record metadata, independently of solver quality.
counts=cellfun(@(r)r.meta.N,records); largest=max(counts);
candidates=records(counts==largest);
dates=sort(unique(cellfun(@(r)r.meta.date,candidates,'UniformOutput',false)));
date=dates{1}; data=records(cellfun(@(r)strcmp(r.meta.date,date),records));
first=find(cellfun(@(r)isfield(r.result,'x0'),data),1);
if isempty(first), return; end
h=data{first}; x0=h.result.x0; T=size(x0,2); t=(0:T)*h.meta.dt;
fig=newfigure(manifest,1); ax=axes(fig); hold(ax,'on'); styleaxes(ax);
initial=sum(x0,1);
handles=stairs(ax,t,[initial initial(end)],'Color',[.5 .5 .5],...
    'LineStyle',':','LineWidth',1.7); names={'Uniform feasible start'};
for m=1:numel(methods)
    d=select(data,'',methods(m).key);
    if isempty(d) || ~isfield(d{1}.result,'x'), continue; end
    profile=sum(d{1}.result.x,1); [color,style]=method_style(methods(m),colors(m,:));
    handles(end+1)=stairs(ax,t,[profile profile(end)],'Color',color,...
        'LineStyle',style,'LineWidth',1.4); %#ok<AGROW>
    names{end+1}=methods(m).name; %#ok<AGROW>
end
xlabel(ax,'Local time (h)'); ylabel(ax,'Aggregate charging power (kW)');
title(ax,sprintf('%s, N = %d',date,largest),'Interpreter','none');
if manifest.cfg.synthetic_ev_for_smoke, title(ax,'Synthetic EV software check'); end
xlim(ax,[0,24]); xticks(ax,0:3:24);
legend(ax,handles,names,'Location','southoutside','NumColumns',4,...
    'Box','off','Interpreter','none','FontSize',9);
savefigure(fig,folder,'ev_load_profile'); close(fig);
end

function data=select(records,id,key)
if isempty(records), data={}; return; end
keep=true(size(records));
if ~isempty(id), keep=keep & cellfun(@(r)strcmp(r.meta.model_id,char(id)),records); end
if ~isempty(key), keep=keep & cellfun(@(r)strcmp(r.meta.method_key,char(key)),records); end
data=records(keep);
end
function [color,style]=method_style(method,fallback)
style='-';
switch method.key
    case 'nm', color=[.20 .20 .20];
    case 'i010', color=[.00 .447 .741];
    case 'i020', color=[.850 .325 .098];
    case 'i025', color=[.466 .674 .188];
    case 'nm_fast', color=[.494 .184 .556]; style='--';
    case 'eg', color=[.635 .078 .184]; style=':';
    otherwise, color=fallback; style='-.';
end
end
function fig=newfigure(manifest,panels)
if panels==2, width=9.2; else, width=7.2; end
fig=figure('Visible',manifest.cfg.figure_visible,'Color','w','Units','inches',...
    'Position',[1 1 width 4.3],'InvertHardcopy','off');
end
function styleaxes(ax)
set(ax,'Color','w','XColor','k','YColor','k','FontName','Times New Roman',...
    'FontSize',10,'LineWidth',.8,'GridColor',[.65 .65 .65],'GridAlpha',.3,...
    'MinorGridAlpha',.15,'Box','on'); grid(ax,'on');
end
function savefigure(fig,folder,stem)
drawnow;
exportgraphics(fig,fullfile(folder,[stem,'.png']),'Resolution',300,'BackgroundColor','white');
exportgraphics(fig,fullfile(folder,[stem,'.pdf']),'ContentType','vector','BackgroundColor','white');
end
