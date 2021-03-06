
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%           PREPROC, MODELS, ETC.                                       %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function e3_wrapper_runAnalyses_gj(do,cfg)
    matlabbatch = [];

    %%       12. if just quality check of SDC and coreg, don't need parallel proc
    %%-----------------------------------------------------------------
    if ( do.PREPROC.p12_qualCheck && sum(structfun(@sum, do.PREPROC)) == 1 )
            for ss = 1: do.nSs
                subj   = do.Ss(ss);
                subjID = sprintf('sub%03d',subj);
                fprintf('************ subject %d [%s] ************\n',subj, datetime('now'));

                sdirs = e3_set_sdirs(cfg.dirs.sub,subjID) 

                chkImgsSDCreg(sdirs,cfg,'norm2mni'); 
            end
    elseif ( do.PREPROC.p07b_coregChk && sum(structfun(@sum, do.PREPROC)) == 1 )
            for ss = 1: do.nSs
                subj   = do.Ss(ss);
                subjID = sprintf('sub%03d',subj);
                fprintf('************ subject %d [%s] ************\n',subj, datetime('now'));

                sdirs = e3_set_sdirs(cfg.dirs.sub,subjID) 

                chkImgsSDCreg(sdirs,cfg,'coreg'); 
            end
    elseif do.PREPROC.p09b_dartelNormChk
        PREPROC_dartelNormChk(cfg);
    end
    
    if do.PREPROC.p13_meanEPI || do.PREPROC.p13b_meanT1 
        files2mean = cell(do.nSs,1);
        
        if do.PREPROC.p13_meanEPI
            filematch    = '^wmu2meanuafPRISMA.*.nii';  % each subj's mean
            fileout      = 'mean_wmu2meanEPI.nii';
        elseif do.PREPROC.p13b_meanT1
             filematch    = '^wmsPRISMA.*.nii';
             fileout      = 'mean_wmT1.nii';
             
 
        end

        for ss = 1:do.nSs
            searchdir = '';

            subjID    = sprintf('sub%03d',do.Ss(ss));
            sdirs     = e3_set_sdirs(cfg.dirs.sub,subjID); 

            if do.PREPROC.p13_meanEPI
                searchdir    = fullfile(sdirs.gridC,'run1');
            elseif do.PREPROC.p13b_meanT1
                searchdir    = sdirs.T1;
            end

            files2mean{ss} = spm_select('FPList',searchdir, filematch ); 

        end
    
        fprintf('.....averaging images across %d Ss to create %s ......\n',do.nSs,fileout);
        avgImg(files2mean, fullfile(cfg.dirs.grp, fileout));
    
    else
        
        spm_jobman('initcfg')
        batchErrs = cell(do.nSs);


        %% what are we doing? to log output into a file
        iconsec = diff(do.Ss)==1;
        iconsec = [true iconsec]; % diff is length-1 (diff of pairs), so add 1st elem back
        ijumps  = find(iconsec==0);

        iic      = 1;
        strSub   = '';
        for ii=1:length(ijumps)
            strSub = sprintf('%ssub%03d-%03d.',strSub,do.Ss(iic),do.Ss(ijumps(ii)-1));
            iic = ijumps(ii);
        end

        % grab the last few
        if ijumps < do.nSs
            strSub = sprintf('%ssub%03d-%03d.',strSub,do.Ss(end),do.Ss(end));
        end

        %strSub = sprintf('sub%s',sprintf('_%d',do.Ss));

        todo = fieldnames(do);

        strTask  = '';
        sstrTask = '';

        for tt = 1:length(todo)
            dostep = todo{tt}; % PREPROC, delete_realign, lev1, lev2
            if strcmp(dostep,'tasks') || strcmp(dostep,'nSs') || strcmp(dostep,'Ss')  || strcmp(dostep,'EPIres') || strcmp(dostep,'TESTING')
                continue
            end
            dostep2 = fieldnames(do.(dostep));
            doset  = cell2mat( struct2cell( do.(dostep) ) );

            ido = find( doset > 0 );
            if ~isempty(ido)
                doset2 = dostep2(ido);
                sstrTask = sprintf('_%s',doset2{:});
                strTask = sprintf('%s%s%s.',strTask,dostep,sstrTask);
            end
        end

        cfg.dirs.log = fullfile(cfg.dirs.scripts,'logs');
        if ~exist(cfg.dirs.log,'dir')
            mkdir(cfg.dirs.log);
        end

        logfn = sprintf('%s%s%slog',cfg.logpref,strTask,strSub);
        diary(fullfile(cfg.dirs.log,logfn));


        fprintf('============== SCRIPT STARTED [%s] ===========\n', datetime('now'));

        
  


        
        %%       9.  NORMALIZE w/DARTEL -- do TEMPLATE outside subj/task loop
        %%            cos need to 1st gather files across all Ss before running batch
        %%-----------------------------------------------------------------
        if do.PREPROC.p09_normalize && strcmp(cfg.PREPROC.normalize,'DARTEL') && ( do.PREPROC.p09dari_template_T1 || do.PREPROC.p09dari_template_EPI )
            %% INPUTS:
            %%   * indiv's imported GM rc1*.nii 
            %%   * indiv's imported WM rc2*.nii 
            %% OUTPUTS:
            %%   * flow field u_rc1*.nii (per subj)
            %%   * Template_[1-6].nii (for the 1st subj called)
            
            %% DARTEL: (imported) imgs go through iterative procedure where
            %% initial template is created that is a mean of grey and white 
            %% matter across all participants. Deformation from the initial 
            %% template to each individual's grey and white matter images is 
            %% then computed and the inverse of the deformation applied to 
            %% each individual's images. A second template is then created 
            %% as the mean of the deformed individuals' grey and white matter 
            %% images across all participants, and this procedure is repeated 
            %% until a sixth template is created. 
            %% To normalize with DARTEL, the realigned and resliced fMRI 
            %% and the flow field grey matter image are nonlinearly 
            %% normalised to the sample-specific template for each individual 
            %% independently and affine-aligned into MNI space. 
                    
            c1 = strings([do.nSs,1]);
            c2 = strings([do.nSs,1]);
            
            for ss = 1:do.nSs 
                subj   = do.Ss(ss);
                subjID = sprintf('sub%03d',subj);
                sdirs  =  e3_set_sdirs(cfg.dirs.sub,subjID);

                if do.PREPROC.p09dari_template_T1
                    %% Dartel-imported r* files
                    c1(ss)  = spm_select('FPList', sdirs.T1, '^rc1sPRIS.*\.nii$');
                    c2(ss)  = spm_select('FPList', sdirs.T1, '^rc2sPRIS.*\.nii$'); 
                    suffix  = 'Template';
                elseif do.PREPROC.p09dari_template_EPI                 
                    %% trying with tissue segmentations of EPIs
                    %% https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind1001&L=SPM&P=R15634&K=2 
                    %% Bas Neggers has done this:
                    %% On some occasions I actually did use a mean EPI from high-resolution 
                    %% (2x2x2 mm^3) fMRI data at 3T for 'unified segmentation'. It did result 
                    %% in GM and WM probability maps that looked good enough for 9 out of 10 
                    %% subjects, and hence I used the ensuing normalization parameters for the 
                    %% EPIs. I only got this working on high resolution EPI as there was quite 
                    %% usuable anatomical contrast in them, I indeed think at low resolutions 
                    %% EPI (eg 4x4x4 mm^3) this shouldn't be attempted. 

                    c1(ss)  = spm_select('FPList', fullfile(sdirs.gridC, 'run1'), '^rc1mu2mean.*\.nii$');
                    c2(ss)  = spm_select('FPList', fullfile(sdirs.gridC, 'run1'), '^rc2mu2mean.*\.nii$'); 
                    suffix  = 'TemplateEPIra';  % TemplateEPI - no DARTEL-imported, TemplateEPIr - DARTEL-imported, TemplateEPIra - DARTEL-imported + affine-reg (MNI to EU brains)
                end
                
                %% for ss=1:size(ec1,1)
                %%    ss
                %%    size(niftiread(ec1{ss}))
                %% end
                %% subj 95 = sub098
            end

            if cfg.PREPROC.normalize_dartel_grpTempCreate  % create template from the group of subjects
                %% outputs Template_6.nii file in the 1st subject processed
                subjobs{1}.spm.tools.dartel.warp.images{1}                = cellstr(c1);
                subjobs{1}.spm.tools.dartel.warp.images{2}                = cellstr(c2);
                subjobs{1}.spm.tools.dartel.warp.settings.template        = suffix;
                subjobs{1}.spm.tools.dartel.warp.settings.rform           = 0;
                subjobs{1}.spm.tools.dartel.warp.settings.param(1).its    = 3;
                subjobs{1}.spm.tools.dartel.warp.settings.param(1).rparam = [4 2 1e-06];
                subjobs{1}.spm.tools.dartel.warp.settings.param(1).K      = 0;
                subjobs{1}.spm.tools.dartel.warp.settings.param(1).slam   = 16;
                subjobs{1}.spm.tools.dartel.warp.settings.param(2).its    = 3;
                subjobs{1}.spm.tools.dartel.warp.settings.param(2).rparam = [2 1 1e-06];
                subjobs{1}.spm.tools.dartel.warp.settings.param(2).K      = 0;
                subjobs{1}.spm.tools.dartel.warp.settings.param(2).slam   = 8;
                subjobs{1}.spm.tools.dartel.warp.settings.param(3).its    = 3;
                subjobs{1}.spm.tools.dartel.warp.settings.param(3).rparam = [1 0.5 1e-06];
                subjobs{1}.spm.tools.dartel.warp.settings.param(3).K      = 1;
                subjobs{1}.spm.tools.dartel.warp.settings.param(3).slam   = 4;
                subjobs{1}.spm.tools.dartel.warp.settings.param(4).its    = 3;
                subjobs{1}.spm.tools.dartel.warp.settings.param(4).rparam = [0.5 0.25 1e-06];
                subjobs{1}.spm.tools.dartel.warp.settings.param(4).K      = 2;
                subjobs{1}.spm.tools.dartel.warp.settings.param(4).slam   = 2;
                subjobs{1}.spm.tools.dartel.warp.settings.param(5).its    = 3;
                subjobs{1}.spm.tools.dartel.warp.settings.param(5).rparam = [0.25 0.125 1e-06];
                subjobs{1}.spm.tools.dartel.warp.settings.param(5).K      = 4;
                subjobs{1}.spm.tools.dartel.warp.settings.param(5).slam   = 1;
                subjobs{1}.spm.tools.dartel.warp.settings.param(6).its    = 3;
                subjobs{1}.spm.tools.dartel.warp.settings.param(6).rparam = [0.25 0.125 1e-06];
                subjobs{1}.spm.tools.dartel.warp.settings.param(6).K      = 6;
                subjobs{1}.spm.tools.dartel.warp.settings.param(6).slam   = 0.5;
                subjobs{1}.spm.tools.dartel.warp.settings.optim.lmreg     = 0.01;
                subjobs{1}.spm.tools.dartel.warp.settings.optim.cyc       = 3;
                subjobs{1}.spm.tools.dartel.warp.settings.optim.its       = 3;
            elseif ~isempty(cfg.PREPROC.normalize_dartel_grpTempSubnr2use)
                subRef   = sprintf('sub%03d',cfg.PREPROC.normalize_dartel_grpTempSubnr2use);
                sRefdirs = e3_set_sdirs(cfg.dirs.sub,subRef); 
                    
                    
                subjobs{1}.spm.tools.dartel.warp1.images{1}                  = cellstr(rc1);
                subjobs{1}.spm.tools.dartel.warp1.images{2}                  = cellstr(rc2);
                subjobs{1}.spm.tools.dartel.warp1.settings.rform             = 0;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).rparam   = [4 2 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).K        = 0;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).template = { spm_select('FPList', sRefdirs.T1, '^Template_1.*\.nii$') };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).rparam   = [2 1 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).K        = 0;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).template = { spm_select('FPList', sRefdirs.T1, '^Template_2.*\.nii$')  };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).rparam   = [1 0.5 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).K        = 1;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).template = { spm_select('FPList', sRefdirs.T1, '^Template_3.*\.nii$')  };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).rparam   = [0.5 0.25 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).K        = 2;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).template = { spm_select('FPList', sRefdirs.T1, '^Template_4.*\.nii$')  };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).rparam   = [0.25 0.125 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).K        = 4;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).template = { spm_select('FPList', sRefdirs.T1, '^Template_5.*\.nii$')  };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).rparam   = [0.25 0.125 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).K        = 6;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).template = { spm_select('FPList', sRefdirs.T1, '^Template_6.*\.nii$')  };
                subjobs{1}.spm.tools.dartel.warp1.settings.optim.lmreg       = 0.01;
                subjobs{1}.spm.tools.dartel.warp1.settings.optim.cyc         = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.optim.its         = 3;      
                
            else
                % use template already created elsewhere -- here use the VBM8 toolbox templates

                subjobs{1}.spm.tools.dartel.warp1.images{1}                  = cellstr(rc1);
                subjobs{1}.spm.tools.dartel.warp1.images{2}                  = cellstr(rc2);
                subjobs{1}.spm.tools.dartel.warp1.settings.rform             = 0;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).rparam   = [4 2 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).K        = 0;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(1).template = { fullfile(cfg.dirs.VBM, 'Template_1_IXI555_MNI152.nii') };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).rparam   = [2 1 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).K        = 0;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(2).template = { fullfile(cfg.dirs.VBM, 'Template_2_IXI555_MNI152.nii') };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).rparam   = [1 0.5 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).K        = 1;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(3).template = { fullfile(cfg.dirs.VBM, 'Template_3_IXI555_MNI152.nii') };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).rparam   = [0.5 0.25 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).K        = 2;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(4).template = { fullfile(cfg.dirs.VBM, 'Template_4_IXI555_MNI152.nii') };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).rparam   = [0.25 0.125 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).K        = 4;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(5).template = { fullfile(cfg.dirs.VBM, 'Template_5_IXI555_MNI152.nii') };
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).its      = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).rparam   = [0.25 0.125 1e-06];
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).K        = 6;
                subjobs{1}.spm.tools.dartel.warp1.settings.param(6).template = { fullfile(cfg.dirs.VBM, 'Template_6_IXI555_MNI152.nii') };
                subjobs{1}.spm.tools.dartel.warp1.settings.optim.lmreg       = 0.01;
                subjobs{1}.spm.tools.dartel.warp1.settings.optim.cyc         = 3;
                subjobs{1}.spm.tools.dartel.warp1.settings.optim.its         = 3;            
            end
            
            spm_jobman('run', subjobs);
%         elseif do.PREPROC.p09_normalize && strcmp(cfg.PREPROC.normalize,'DARTEL') && do.PREPROC.p09dariii_MNIspace_est          
%             %%       9iii.  NORMALIZE w/DARTEL -- est. affine transform to MNI space 
%             %%-----------------------------------------------------------------
%             sub1   = sprintf('sub%03d',do.Ss(1));
%             s1dirs = e3_set_sdirs(cfg.dirs.sub,sub1); 
%             templ = spm_select('FPList', s1dirs.T1, '^Template_6.*\.nii$');
% 
%             %% INPUT:
%             %%   * DARTEL Template_6.nii
%             %%   * GM TPM 
%             %% OUTPUT:
%             %%   * Template_6_sn.mat (affine transform that will bring the dartel warped images into MNI space) 
%             Vm       = spm_vol(fullfile(s1dirs.T1,'Template_6.nii,1')); 
%             matname  = [spm_str_manip(Vm.fname,'sd') '_sn.mat'];
%             VG       = fullfile(cfg.dirs.SPM,'tpm/TPM.nii,1');
%             params   = spm_normalise(VG,Vm,matname,'',''); % use old spm_normalise because new one will try and segment
            
%             
%             subjobs{1}.spm.spatial.normalise.est.subj.vol = { fullfile(s1dirs.T1,'Template_6.nii') };
%             subjobs{1}.spm.spatial.normalise.est.eoptions.biasreg = 0.0001;
%             subjobs{1}.spm.spatial.normalise.est.eoptions.biasfwhm = 60;
%             subjobs{1}.spm.spatial.normalise.est.eoptions.tpm = {fullfile(cfg.dirs.SPM,'tpm/TPM.nii,1')}; % GM
%             subjobs{1}.spm.spatial.normalise.est.eoptions.affreg = 'mni';
%             subjobs{1}.spm.spatial.normalise.est.eoptions.reg = [0 0.001 0.5 0.05 0.2];
%             subjobs{1}.spm.spatial.normalise.est.eoptions.fwhm = 0;
%             subjobs{1}.spm.spatial.normalise.est.eoptions.samp = 3;
%             
%             spm_jobman('run', subjobs);
%             
        else
            if ~do.TESTING
%                 delete(gcp('nocreate'));  % ensure no parallel pool is running
%                 thiscluster            = parcluster('local');
%                 thiscluster.NumWorkers = cfg.ncores;
%                 parpool('local',cfg.ncores);  

                parfor ss = 1: do.nSs
                    doWithinSubj(do,cfg,ss); %% runs spm batch job
                end

%                delete(gcp('nocreate'));
            else

                for ss = 1: do.nSs
                   doWithinSubj(do,cfg,ss); %% runs spm batch job
                end      
            end 
            
        end
        
        fprintf('============== SCRIPT FINISHED [%s] ===========\n', datetime('now'));
        save(fullfile(cfg.dirs.log,sprintf('%s%s%sbatchErrs.mat',cfg.logpref,strTask,strSub)),'batchErrs');
        diary off

    end
end  





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  %%                                                               %%  %%
%%  %%           fcn to run batch jobs within subj loop              %%  %%
%%  %%                                                               %%  %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function doWithinSubj(do,cfg,ss)
        matlabbatch = [];

        subj   = do.Ss(ss);
        subjID = sprintf('sub%03d',subj);
        fprintf('************ subject %d [%s] ************\n',subj, datetime('now'));
        sdirs  =  e3_set_sdirs(cfg.dirs.sub,subjID);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%.....................  do NOT do for each task .................
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%                   3. REALIGN & UNWARP (all tasks together to 1st task) 
        %%-----------------------------------------------------------------
        %%
        %% Tobias says legacy at ISfN is to do realign+unwarp, as MP 
        %% regressors risk lowering task-related activity.
        if do.PREPROC.p03_realignNwarp
            subjobs = PREPROC_realignNwarp(do.tasks,sdirs);
            matlabbatch = [matlabbatch, subjobs];     
        end
        
        %%                   6.  apply SDC (no estimation)
        %%-----------------------------------------------------------------  
        %% HySCO_write.m might only work in non-parallel mode??
        if do.PREPROC.p06x_SDCapplyEstOnly
            sdirs = e3_reset_sdirs(sdirs,'GE');
            subjobs = PREPROC_SDCapplyEstOnly(sdirs);
            matlabbatch = [matlabbatch, subjobs];
        end
        
        %%                  7.  COREGISTER T1w to mean fcnl img of 1st task
        %%-----------------------------------------------------------------
        if do.PREPROC.p07_coregT1toEPI 
            subjobs = PREPROC_coregT1toEPI(cfg.PREPROC.coreg,subjID,'gridC',fullfile(sdirs.subj, 'func','gridC'),sdirs.T1,cfg.dirs.fsl);
            matlabbatch = [matlabbatch, subjobs]; 
        end 
        
        %%                   8a. SEGMENT T1 into tissue maps, skull strip, create brain mask from T1
        %%-----------------------------------------------------------------
        %%        
%         if do.PREPROC.p08_segSkullstripMask
%             subjobs = PREPROC_segT1SkullstripMask(sdirs.T1,cfg.dirs.SPM); % passing matlabbatch because need to run batch to run SPM jobs before the rest of the steps in this step
%             matlabbatch = [matlabbatch, subjobs]; 
%         end

        %%                   8b. SEGMENT EPI into tissue maps
        %%-----------------------------------------------------------------
        %%        
        if do.PREPROC.p08_segSkullstripMask
            subjobs = PREPROC_segEPI(fullfile(sdirs.subj, 'func','gridC'),cfg.dirs.SPM); % passing matlabbatch because need to run batch to run SPM jobs before the rest of the steps in this step
            matlabbatch = [matlabbatch, subjobs]; 
        end 


 
            
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%.....................  TASK-DEPENDENT STEPS .................
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        for tt=1:length(do.tasks)
            do.task = do.tasks{tt};
            fprintf('________task %s ************\n',do.task);

            sdirs.task = fullfile(sdirs.subj, 'func',do.task);  



            %%                   1.  MOVE DUMMIES                          
            %%-----------------------------------------------------------------
            if do.PREPROC.p01_dummies
                PREPROC_mvDummies(sdirs.task,cfg.MRI.ndummies);
            end


            %%                   2.  SLICE-TIMING CORRECTION                          
            %%-----------------------------------------------------------------
            if do.PREPROC.p02_ST   
                subjobs = PREPROC_ST(sdirs.task,cfg);
                matlabbatch = [matlabbatch, subjobs]; 
            end


%                 %%                   3. REALIGN & UNWARP  ==>> MOVED OUTSIDE OF TASK LOOP!
%                 %%-----------------------------------------------------------------
%                 %%
%                 %% Tobias says legacy at ISfN is to do realign+unwarp, as MP 
%                 %% regressors risk lowering task-related activity.
%                 if do.PREPROC.p03_realignNwarp
%                     subjobs = PREPROC_realignNwarp(sdirs.task);
%                     matlabbatch = [matlabbatch, subjobs];     
%                 end

            %%                   8b. SEGMENT EPI into tissue maps
            %%-----------------------------------------------------------------
            %%        
%             if do.PREPROC.p08_segSkullstripMask
%                 subjobs = PREPROC_segEPI(sdirs.task,cfg.dirs.SPM); % passing matlabbatch because need to run batch to run SPM jobs before the rest of the steps in this step
%                 matlabbatch = [matlabbatch, subjobs]; 
%             end


            %%                   4.  SPIKE tagging
            %%-----------------------------------------------------------------
            if do.PREPROC.p04a_spikeTag
                PREPROC_SPIKES(subjID,do.task,sdirs.task,cfg.PREPROC.spikeThresh);
            end

            if do.PREPROC.p04b_spikePlot
                PREPROC_SPIKEPLOT(subjID,do.task,sdirs.task,cfg.PREPROC.spikeThresh,cfg.dirs.log);
            end

            %%                   6. COPY EPI dirs for the various preprocessing approaches
            %%-----------------------------------------------------------------
            %%
            %%  MRI/indiv/subXXX/
            %%                   anat/
            %%                   func/
            %%                   revBlipEPI/
            %%                              GRE/
            %%                    lt          SE/
            %% will copy the realigned-unwarped files in func into func2
%             if do.PREPROC.p06_cpDirs
%                 system( sprintf('mkdir %s; find %s -name *uaf* -exec cp --parents {} %s \;',...
%                                        fullfile(sdirs.subj,'func_ua'),...
%                                        sdirs.fcn, ...
%                                        fullfile(sdirs.subj,'func_ua')...
%                                     ));
%             end

            %%                   6.  susceptibility DISTORTION CORREX                        
            %%-----------------------------------------------------------------
            if do.PREPROC.p06a_SDCreorganize
                sdirs = e3_orgBlips(sdirs);
            end

            if do.PREPROC.p06b_SDC
                sdirs = e3_reset_sdirs(sdirs,'GE');
                subjobs = PREPROC_SDC(do.task,sdirs,cfg);
                matlabbatch = [matlabbatch, subjobs]; 
            end


%             %%                   8.  COREGISTER T1w to functional images
%             ===>>>> MOVED OUTSIDE OF TASK LOOP
%             %%-----------------------------------------------------------------
%             if do.PREPROC.p07_coregT1toEPI 
%                 subjobs = PREPROC_coregT1toEPI(cfg.PREPROC.coreg,subjID,task,sdirs.task,sdirs.T1,cfg.dirs.fsl);
%                 matlabbatch = [matlabbatch, subjobs]; 
%             end  
            if do.PREPROC.p06c_flattenMeanU2EPI 
                meanEPI = spm_select('FPList',fullfile(sdirs.task,'run1'),'^u2meanuaf.*nii$');
                if isempty(meanEPI)
                    sprintf('SDCd file for subject %s does not exist to correct intensity bias: %s',subjID, fullfile(sdirs.task));
                else
                    flattenGE(meanEPI,cfg.dirs.SPM);
                end
            end
    
      %  do.PREPROC.p09dari_template_EPI
               
                

            %%                   9.  NORMALIZE
            %%-----------------------------------------------------------------
            if do.PREPROC.p09_normalize 
                if (strcmp(cfg.PREPROC.normalize,'DARTEL') && ( do.PREPROC.p09darii_applyNorm_EPI || do.PREPROC.p09darii_applyNorm_T1 ))
                    subjobs = PREPROC_normalize(ss,sdirs,cfg,do);
                    matlabbatch = [matlabbatch, subjobs]; 
                end
            end


            %%                   10.  SMOOTH
            %%-----------------------------------------------------------------
            if do.PREPROC.p10_smooth
                subjobs = PREPROC_smooth(sdirs.task,cfg.MRI.sliceThickEPI);
                matlabbatch = [matlabbatch, subjobs]; 
            end

            %%                   12. quality check of SDC and coreg
            %%-----------------------------------------------------------------
            if do.PREPROC.p12_qualCheck
                chkImgsSDCreg(sdirs,cfg); 
            end
            
            %%                   13. prepping for model - get events
            %%-----------------------------------------------------------------
%             if do.LEV1.grid_get_events
%                
%         
%             end
        end  

        if size(matlabbatch,1) > 0
            try
                batchErrs{ss} = {subjID,spm_jobman('run', matlabbatch)};
            catch
                batchErrs{ss} = {subjID,"failed"};
            end
        end  
end
%%%%%%%%%%%%%%%%%%   END SUBJ-internal batches   %%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
