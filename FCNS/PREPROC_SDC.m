%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                   3SUSCEPTIBILITY DISTORTION CORREX   
%%   
%%-----------------------------------------------------------------
function [jobs,ublip_p,ublip_d] = PREPROC_SDC(task,sdirs,cfg)
    jobs = [];
    jj = 0;
    filesAllRuns = [];
    
    others2SDC_p = [];
    others2SDC_d = [];
    blip_d       = [];
    blip_p       = [];
    ublip_d      = [];
    ublip_p      = [];
            
    cd(sdirs.task)
    
    nses = length( get_subfolders(sdirs.ge) )/2;
            
    if exist(sdirs.se,'dir') 
        cfg.PREPROC.SDC.seq = 'SE';  % if SE blips exist, use this over GE
    else
        cfg.PREPROC.SDC.seq = 'GE';
    end
    
    switch cfg.PREPROC.SDC.seq
        case 'FM' % field map
            %% magnitude    
            shortmag = spm_select('ExtFPList', w.fieldmapPath,[w.prefix.fieldmap_mag '.*\.nii$'], 1:1); 

            %% phase difference in radian
            phase_diff = spm_select('FPList', w.fieldmapPath,[w.prefix.fieldmap_phase '.*\.nii$']); 

            %% Get the T1 template  
            path_FielpMap = which('Fieldmap');
            [path, ~, ~] = fileparts(path_FielpMap);
            template	=   fullfile(path, 'T1.nii');

            %% Get T1 structural file
            anatFile    =   spm_select('FPList', w.T1Path, ['^' w.subName   '.*' w.anat_ref '.*\.nii$']); 

            %% Get the fisrt EPI file removing dummy files    
            EPIfile = spm_select('ExtFPList',  fullfile(w.funcPath, w.sessions{1}), ['^' w.subName  '.*\.nii$'], 1:1); 

            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.data.presubphasemag.phase            = cellstr(phase_diff);
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.data.presubphasemag.magnitude        = cellstr(shortmag);   
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.et              = [w.SHORT_ECHO_TIME w.LONG_ECHO_TIME];
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.maskbrain       = 0;    % 1= Magnitude Image is choosed to generate Mask Brain
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.blipdir         = 1;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.tert            = w.READOUT_TIME; % readout time
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.epifm           = 0;    % non-EPI bases fieldmap
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.ajm             = 0;    % Jacobian use do not use
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.uflags.method   = 'Huttonish';    
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.uflags.fwhm     = 10;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.uflags.pad      = 15;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.uflags.ws       = 1;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.mflags.template = cellstr(template);
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.mflags.fwhm     = 5;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.mflags.nerode   = 2;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.mflags.ndilate  = 4;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.mflags.thresh   = 0.5;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.defaults.defaultsval.mflags.reg      = 0.02;  
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.session.epi                          = cellstr(EPIfile);  
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.matchvdm                             = 0;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.sessname                             = 'session';
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.writeunwarped                        = 0;
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.anat                                 = cellstr(anatFile);
            jobs{1}.spm.tools.fieldmap.calculatevdm.subj.matchanat                            = 0; 


        
        case 'GE'
            %% for the blip-reverse EPI GE scans 
            direcs = {'p','d'};

            
            for bb=1:nses
                system(sprintf('gunzip -f %s',fullfile(sdirs.ge_d{bb},'*.gz')));
                system(sprintf('gunzip -f %s',fullfile(sdirs.ge_p{bb},'*.gz')));

                blip_ds   = spm_select('FPList', sdirs.ge_d{bb}, '^f.*.nii');
                blip_ps   = spm_select('FPList', sdirs.ge_p{bb}, '^f.*.nii');
                                
                %% take the average of the GEs
                fprintf('______Averaging the GEs______\n');
                ngre_d    = size(blip_ds,1);               

                blip_d{bb} = fullfile(sdirs.ge_d{bb}, sprintf('avg_blipGE%d_d.nii',bb) );
                blip_p{bb} = fullfile(sdirs.ge_p{bb}, sprintf('avg_blipGE%d_p.nii',bb) );
%                 avgImg(blip_ds   , blip_d{bb});
%                 avgImg(blip_ps, blip_p{bb});

                %%...........a). clean up/normalize intensity only if creating a fieldmap from GE because need to flatten the intensity map.......
                fprintf('________a1). Cleaning up for GE blip down___________\n');
                fprintf('\t\t %s\n',blip_d{bb});
%                 flattenGE(blip_d{bb},cfg.dirs.SPM);

                fprintf('________a2). Cleaning up for GE blip up___________\n');
                fprintf('\t\t %s\n',blip_p{bb});
%                 flattenGE(blip_p{bb},cfg.dirs.SPM);

                % feed the flattened images to the rest of the pipeline
                [tmp_path, tmp_name, tmp_ext] = fileparts(blip_d{bb});
                mblip_d{bb} = sprintf('m%s%s',tmp_name,tmp_ext);
                blip_d{bb} = fullfile(tmp_path, mblip_d{bb});

                [tmp_path, tmp_name, tmp_ext] = fileparts(blip_p{bb});
                mblip_p{bb} = sprintf('m%s%s',tmp_name,tmp_ext);
                blip_p{bb} = fullfile(tmp_path, mblip_p{bb});

                others2SDC_p{bb} = blip_p{bb};
                others2SDC_d{bb} = blip_d{bb};
            end
        %%................ SPIN ECHO .........................    
        case 'SE'
            dirSrcSeq = sdirs.se;
            sedirnames = get_subfolders( dirSrcSeq );
           
            idir_blip_ds = ~cellfun(@isempty, regexp(sedirnames, '.*SE.*_d'));
            dir_blip_ds  = {sedirnames{idir_blip_ds}};
            nses = length(dir_blip_ds);
             
            idir_blip_ps = ~cellfun(@isempty, regexp(sedirnames, '.*SE.*_p'));
            dir_blip_ps  = {sedirnames{idir_blip_ps}};
            
            for bb=1:nses
                blip_ds   = spm_select('FPList', sdirs.se_d{bb}, '^s.*.nii');
                blip_ps   = spm_select('FPList', sdirs.se_p{bb}, '^s.*.nii');

                % 1st one is SBref (contains the single-band reference data 
                % that are needed to do the multiband reco). 
                % 2nd = series without SBref -- equiv to SBref but closer to the fMRI data.   
                blip_d{bb}  = blip_ds(2,:); 
                blip_p{bb}  = blip_ps(2,:); 

                others2SDC_d{bb} = blip_d{bb};
                others2SDC_p{bb} = blip_p{bb};
            end
            
        otherwise
            warning('!!! Sequence specified (%s) for susceptibility distortion correction not recognized',cfg.PREPROC.SDC.seq);
    end

    fmrisGC = [];
    fmrisRL = [];

    dirGC   = fullfile(sdirs.fcn,'gridC');
    dirRL   = fullfile(sdirs.fcn,'reinfL');

    runsGC  = get_subfolders(dirGC);
    runsRL  = get_subfolders(dirRL);

    %% bias-correct mean functional
    tmpmean  = spm_select('FPList',fullfile(dirGC,'run1'),  '^mean.*.nii');
    
    for rr=1:length(runsGC)
        therun = runsGC{rr};
        tmpfiles = spm_select('FPList',fullfile(dirGC,therun),  '^uaf.*.nii');    % realign and unwarped + time-slice corrected
        if rr == 1
            %tmpmmean  = spm_select('FPList',fullfile(dirGC,therun),  '^mmean.*.nii'); % use bias-corrected mean
            %fmrisGC  = [fmrisGC; cellstr(tmpfiles); cellstr(tmpmmean)];
            fmrisGC  = [fmrisGC; cellstr(tmpfiles); cellstr(tmpmean)];
        else
            fmrisGC  = [fmrisGC; cellstr(tmpfiles)];
        end
    end

    for rr=1:length(runsRL)
        therun = runsRL{rr};
        tmpfiles = spm_select('FPList',fullfile(dirRL,therun), '^uaf.*.nii');
%        tmpmean  = spm_select('FPList',fullfile(dirRL,therun),    %        '^mmean.*.nii'); % realigned RL to GC so mean only in run1 of GC 
        fmrisRL  = [fmrisRL; cellstr(tmpfiles)];
    end

    if nses==1
        %% only 1 blip up/down pair, so add both reinfL and gridC to the list of blip-up files to be SDC'ed
        %% last preproc is realignNwarp, so prefix = u*
        others2SDC_p{1} = [cellstr(others2SDC_p{1}); cellstr(fmrisGC); cellstr(fmrisRL)];
    else
        others2SDC_p{1} = [cellstr(others2SDC_p{1}); cellstr(fmrisGC)];
        others2SDC_p{2} = [cellstr(others2SDC_p{2}); cellstr(fmrisRL)];
    end
            
	fprintf('....TASK %s: \n\t\tSDC tool %s\n\t\t seq %s using %s, scan %s\nNumber of EPIs to correct %d\n', task, cfg.PREPROC.SDC.tool, cfg.PREPROC.SDC.seq, cfg.PREPROC.SDC.nthGE,size(filesAllRuns,1));


    %%............. call specified toolbox to do SDC
    switch cfg.PREPROC.SDC.tool
        case 'ACID' % outputs files prefixed by "u2" (can't change)
             cfg.prefix.SDCed           = 'u2';
             
             for bb=1:nses
                %%...........b). do the correction! the input should be the "cleaned"/flattened images...........
                fprintf('________b). Setting up SDC Hysco2___________\n');
                fprintf('\t\tusing the sources: %s \n\t\tand %s\n',blip_p{bb},blip_d{bb});
                jj = jj + 1;
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.source_up    = {blip_p{bb}}; % need the outer {} -- needed by SPM...ignore Matlab not liking it
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.source_dw    = {blip_d{bb}};
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.others_up    = others2SDC_p{bb};
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.others_dw    = {others2SDC_d{bb}};
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.perm_dim     = 2;
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.dummy_fast   = 1;
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.dummy_ecc    = 0;
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.alpha        = 50;
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.beta         = 10;
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.dummy_3dor4d = 0;
                jobs{jj}.spm.tools.dti.prepro_choice.hysco_choice.hysco2.restrictdim  = [1 1 1];

                [blip_path, blip_fn, blip_ext] = fileparts(blip_p{bb});
                ublip_p{bb} = fullfile(blip_path, sprintf('u2%s%s',blip_fn,blip_ext));

                [blip_path, blip_fn, blip_ext] = fileparts(blip_d{bb});
                ublip_d{bb} = fullfile(blip_path, sprintf('u2%s%s',blip_fn,blip_ext));
             end
        case 'ANTS'
            
        case 'CMTK'
            if strcmp(cfg.PREPROC.SDC.seq,'GE') % for avg vs. nth
                cmtkdirnm = sprintf('CMTK_%s',cfg.PREPROC.SDC.nthGE);
            else
                cmtkdirnm = 'CMTK';
            end
            
            %dirSrcSeq = fullfile( dirRE, dir_blip_d, cmtkdirnm );
            %% dirRE = /projects/estropharm3/data/MRI/indiv/sub041/revBlipEPI/GE
            %% 
            %fullfile( dirRE, cmtkdirnm );
            
            %if ~exist(dirSrcSeq,'dir')
            %	mkdir(dirSrcSeq);
            %end
            %% CMTK-0). Flip rev phase-encoding image  
            %%  otherwise CMTK will overlap the blip-up/down like mirrored images (i.e. not aligned)
            %%       convertx [options] infile outfile
            [blipd_path, blipd_fn, blipd_ext] = fileparts(blip_d{bb});
            blip_d_orig = blip_d{bb};
            blip_d{bb} = sprintf('%s/y%s%s',blipd_path,blipd_fn,blipd_ext);
            
            fprintf('....CMTK-0: Flipping blip-down along y-axis [%s]........\n', datetime('now'));
            fprintf( sprintf('netapp cmtk convertx --flip-y %s %s\n',...
                                                       blip_d_orig, blip_d{bb}) );
             system( sprintf('netapp cmtk convertx --flip-y %s %s',...
                                                        blip_d_orig, blip_d{bb}) );                 
            fprintf('.......CMTK-0 finished [%s].........\n', datetime('now'));
            
            
            %% CMTK-1). compute the deformations needed to unwarp the two opposite-direction phase encoded images: 
            %% the CMTK epiunwarp tool wrapper assumes that data is acquired axially in A/P direction 
            %%    epiunwarp InputImage1 InputImage2 OutputImage1 OutputImage2 OutputDField OutputDFieldRev
            fprintf('....CMTK-1: Computing Jacobian matrix and deformation field [%s]..........\n', datetime('now'));
            
            %% cmtk epiunwarp --write-jacobian-fwd epiunwarp/jacobian_fwd.nii \
            %%                inputs/b0_fwd.nii.gz inputs/b0_rev.nii.gz \
            %%                epiunwarp/b0_fwd.nii epiunwarp/b0_rev.nii epiunwarp/dfield.nrrd
            ublip_p = fullfile(dirSrcSeq,dir_blip_p,'ublip_p.nii');
            ublip_d = fullfile(dirSrcSeq,dir_blip_d,'ublip_d.nii');
            jacob   = fullfile(dirSrcSeq,dir_blip_d,'jacobian_fwd.nii');
            dfield  = fullfile(dirSrcSeq,dir_blip_d,'dfield.nrrd');
            
            fprintf('netapp cmtk epiunwarp --write-jacobian-fwd %s %s %s %s %s %s\n',...
                                                           jacob, blip_p, blip_d{bb}, ublip_p, ublip_d, dfield);
            system( sprintf('netapp cmtk epiunwarp --write-jacobian-fwd %s %s %s %s %s %s\n',...
                                                            jacob, blip_p, blip_d{bb}, ublip_p, ublip_d, dfield));
            fprintf('.......CMTK-1 finished [%s]........\n', datetime('now'));
            
            %% undistort the avg'ed blip-up and blip-down for SE/GE
            others2SDC = [others2SDC_p; others2SDC_d];
           % for rr = 1:length(runs)
           %     run = runs{rr};
          
                %sdirs.run = fullfile(sdirs.task,cfg.PREPROC.SDC_meth,'func'); %fullfile(sdirs.task,run);
                %udirOut = fullfile(dirSrcSeq,'CMTKcorr'); %fullfile(cfg.dirs.sub, sprintf('SDC_%s',cfg.PREPROC.SDC_meth),cmtkdirnm, subj, task, run);
                 
                %if ~exist(udirOut,'dir')
                %    mkdir(udirOut);
                %end
                
%                 files = spm_select('FPList', sdirs.run, '^af.*.nii'); % after slice-timing correction      
%                 [~,filebasenames,~] = cellfun(@fileparts, cellstr(files),'UniformOutput',false);
                for ff = 1:length(others2SDC)
                %for ff = 1:length(filebasenames)
                    file2u = others2SDC{ff};
                    [udirOut, infilebase, ~] = fileparts(others2SDC{ff});
                    %file2u = fullfile(sdirs.run,sprintf('%s.nii',tmpfilebase));
                    
                    fprintf('\t FILE %s\n',file2u); 
                    
                    %% CMTK-2). apply the computed deformation to create an unwarped reformatted image:
                    %          compute reformatted images and Jacobian maps from arbitrary sequences of concatenated transformations 
                    %% cmtk reformatx --floating inputs/b1.nii --linear -o epiunwarp/b1.nii \
                    %%               epiunwarp/b0_fwd.nii epiunwarp/dfield.nrrd
                    ufile = fullfile(udirOut,sprintf('u%s.nii',infilebase)); % reformatted output of reformatx
                    
                    fprintf('===>  CMTK-2: Applying the computed deformation to correct for susceptibility distortion [%s]......\n', datetime('now'));
                    fprintf('netapp cmtk reformatx --floating %s --linear -o %s %s %s\n', ...
                                                    file2u,        ufile, ublip_p, dfield) ;
                     system( sprintf('netapp cmtk reformatx --floating %s --linear -o %s %s %s\n', ...
                                                     file2u,        ufile, ublip_p, dfield) );
                    
                    fprintf('.......CMTK-2 finished [%s]..........\n', datetime('now'));

                    %% CMTK-3). compute the pixel-wise multiplication of the unwarped image with the Jacobian of the deformation => output distortion-corrected image
                    %% cmtk imagemath --in epiunwarp/b1.nii epiunwarp/jacobian_fwd.nii --mul \
                    %%                --out epiunwarp/b1.nii 
                    %% imagemath tool - there are two effects of the distortion on the images: one is a warping along the PE direction, 
                    %% the other is intensity increase or decrease, depending on whether the warping stretches or expands pixels. 
                    %% Basically, you have to multiply (or divide, I can't remember) the original pixel intensity 
                    %% with the Jacobian determinant of the warp at that position to get the corrected intensity. 
                    %% It is simpler to have the two steps be done independently, and because the intensity correction does not involve interpolation, 
                    %% there is no quality penalty from doing the step separately. Also, for DWI the intensity correction would be applied equally 
                    %% to the same pixel in all channels of the DWI, so for most tensor reconstruction methods it would probably not have any 
                    %% effect on the estimated tensor anyway.
                    
                    %rdirOut2 = fullfile(sdirs.task,cfg.PREPROC.SDC_meth,'CMTKcorrIntens');

                    
                   fprintf('....CMTK-3: Pixel-wise computations...outputting distortion-corrected image [%s]........\n', datetime('now'));
                   fprintf('netapp cmtk imagemath --in %s %s --mul --out %s\n', ...
                                                       ufile, jacob, ufile);
                    system( sprintf('netapp cmtk imagemath --in %s %s --mul --out %s\n', ...
                                                        ufile, jacob, ufile) );
                   fprintf('.......CMTK-3 finished [%s].........\n', datetime('now'));



                     %% CMTK-4). correct for subject motion using 3D rigid transformations, which could render unwarping deformation non-applicable
                     %% also corrects for eddy current effects and B0-field distortion  
                     % CMTK's distortion and motion script assumes axially acquired data with phase encoding in the anterior/posterior direction 
                     %system( sprintf('netapp cmtk correct_dwi_distortion_and_motion unwarp_eddy_motion inputs/b0_rev.nii.gz inputs/b0_fwd.nii.gz inputs/b?.nii.gz') );
             %   end
             end           
    end
end


