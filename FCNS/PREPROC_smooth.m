%%-------------------------------------------------------------------------
%%                   9.  SMOOTH
%%-------------------------------------------------------------------------

function jobs = PREPROC_smooth(dirTask,sliceThickEPI)
    EPIs = [];
    runs = get_subfolders(dirTask);
    
    % Get Normalized EPI files of all sessions
    for rr=1:length(runs)
        run = runs{rr};
        
        % Get EPI Realigned files without dummy files
        %f = spm_select('ExtFPList',  fullfile(dirTask, run), '^wua.*\.nii'); 
        %f = spm_select('ExtFPList',  fullfile(dirTask, run), '^wu2ua.*\.nii'); 
        f = spm_select('ExtFPList',  fullfile(dirTask, run), '^u2ua.*_T1res\.nii'); 
        
        EPIs = cellstr(vertcat(EPIs, cellstr(f)));
    end
    jobs{1}.spm.spatial.smooth.data   = EPIs;
    jobs{1}.spm.spatial.smooth.fwhm   = [sliceThickEPI (sliceThickEPI*2) (sliceThickEPI*2)];
    jobs{1}.spm.spatial.smooth.dtype  = 0;
    jobs{1}.spm.spatial.smooth.im     = 0;
    jobs{1}.spm.spatial.smooth.prefix = 's'; 
end