function print_failedGLM2s(subjdata, GCcfg, cfg)
%% print which Ss had failed GLM2 estimations for which ROIs
%% subjdata = table from e3_load_subjInfo()
    here = mfilename('fullpath'); 
    startLogging(here,cfg);

    [failed.alErCL.Ss, failed.alErCL.nXgrp] = e3_get_sexNgrp(subjdata, GCcfg.Ss.failedGLM2.alErC_L);
    [failed.alErCR.Ss, failed.alErCR.nXgrp] = e3_get_sexNgrp(subjdata, GCcfg.Ss.failedGLM2.alErC_R);
    [failed.pmErCL.Ss, failed.pmErCL.nXgrp] = e3_get_sexNgrp(subjdata, GCcfg.Ss.failedGLM2.pmErC_L);
    [failed.pmErCR.Ss, failed.pmErCR.nXgrp] = e3_get_sexNgrp(subjdata, GCcfg.Ss.failedGLM2.pmErC_R);
    
    %% unify which subjects had problems with L or R or both
    failed.alErCL.Ss.alErCL = zeros( size(failed.alErCL.Ss,1), 1);
    failed.alErCR.Ss.alErCR = zeros( size(failed.alErCR.Ss,1), 1);
    failed.pmErCL.Ss.pmErCL = zeros( size(failed.pmErCL.Ss,1), 1);
    failed.pmErCR.Ss.pmErCR = zeros( size(failed.pmErCR.Ss,1), 1);
    
    failed.alErC.Ss = outerjoin(failed.alErCL.Ss,failed.alErCR.Ss,'MergeKeys',true);
    failed.pmErC.Ss = outerjoin(failed.pmErCL.Ss,failed.pmErCR.Ss,'MergeKeys',true);
    failed.ErC.Ss   = outerjoin(failed.alErC.Ss, failed.pmErC.Ss,'MergeKeys',true);
    failed.ErC.Ss   = sortrows(failed.ErC.Ss,{'Sex','GROUP','PbNr'});
    
    failed.ErC.nXgrp = table;
    tmp_sexgrp = strcat(failed.ErC.Ss.Sex,'_',failed.ErC.Ss.GROUP);
        
    tmp_c            = categorical(tmp_sexgrp);
    failed.ErC.nXgrp.sex_grp  = categories(tmp_c);
    failed.ErC.nXgrp.count = countcats(tmp_c);
        
    fprintf('excluded the ff for prob in GLM2 estim for ROI (0 = no GLM2, NaN = no estim prob\n');
    disp(failed.ErC.Ss);
    
    fprintf('exclusion count:\n');
    disp(failed.ErC.nXgrp);
    
end