%%-------------------------------------------------------------------------
%%                   9.  NORMALIZE
%%-------------------------------------------------------------------------
%% notes from Bas Neggers
%%  https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind1302&L=spm&P=R29634&1=spm&9=A&J=on&X=74937E2048C4937D37&d=No+Match%3BMatch%3BMatches&z=4 
%% again
%%  https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind1203&L=spm&P=R42450&1=spm&9=A&J=on&X=74937E2048C4937D37&d=No+Match%3BMatch%3BMatches&z=4 
%% With very crisp high-resolution EPIs (2x2x2) for one study I once 
%% managed to indeed use John's 'unified segmentation' on mean EPIs per 
%% session, and use those parameters for EPI normalization. This worked 
%% well for about 90% of the subjects, and individual inspection of the 
%% results is paramount. For us, at 3x3x3 or 4x4x4 EPIs this was much less 
%% successful, you need quite a bit anatomical contrast in your mean EPI 
%% for this to work IMHO.
%% 
%% With classic EPI normalization to EPI template you will probably reach a 
%% halfway decent result, but I don't expect it to be great. You will 
%% probably need quite some smoothing then to achieve correspondence of 
%% functional representations between subjects. 
%% ...
%% > At the very least, I was able to use unified segmentation on high resolution
%% > 2x2x2 mm³ EPI scans (from 3T scanner) directly, and normalize it without the
%% > use of a T1. As my EPI images had high resolution and pretty good contrast
%% > but were deformed a bit (the former causing the latter) this seemed to be
%% > the best way to reach good normalization. But some caution is warranted: I
%% > had to exclude 1 out of 13 subjects as the EPI of this individual wasnt good
%% > enough to segment. I have the feeling thatin general EPI contrast is a bit
%% > on the edge when trying this. After a functional session I ran 20 whole
%% > brain EPIs (with longer TR to cover the whole brain, my time series had
%% > smaller FOV) with the same angulation and hence deformation as the actual
%% > time series data. I then calculated the average of these 20 EPIs to improve
%% > the contrast. Therefore coregistration of the time series data with that
%% > average was near perfect, and I could subsequently use unified segmentation
%% > for normalization based on that average whole brain EPI. For more, read the
%% > methods in: http://www.ncbi.nlm.nih.gov/pubmed/22235303 

function jobs = PREPROC_normalize(ss,sdirs,cfg,do)

	runs     = get_subfolders(sdirs.task);
%     taskdirs = regexp(sdirs.task, filesep, 'split'); 
%     task     = taskdirs{end};
    
    % Get Sliced EPI images of all runs
    EPIs = {};
    
    for rr = 1:length(runs)
        run = runs{rr};

        dirRun = fullfile(sdirs.task,run);
        cd(dirRun);
        
        img = spm_select('FPList',dirRun,'^u2uaf.*nii$');
        EPIs = cellstr(vertcat(EPIs, cellstr(img)));      
    end
    
        meanEPI = spm_select('FPList',fullfile(sdirs.task,runs{1}),'^mu2meanuaf.*nii$'); 

       switch cfg.PREPROC.normalize
          case 'old'
            jobs{1}.spm.tools.oldnorm.estwrite.subj.source = {meanEPI};
            jobs{1}.spm.tools.oldnorm.estwrite.subj.wtsrc = '';
            jobs{1}.spm.tools.oldnorm.estwrite.subj.resample = EPIs;
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.template = { sprintf('%s/toolbox/OldNorm/EPI.nii,1',cfg.dirs.SPM) };
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.weight = '';
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.smosrc = 8;
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.smoref = 0;
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.regtype = 'mni';
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.cutoff = 25;
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.nits = 16;
            jobs{1}.spm.tools.oldnorm.estwrite.eoptions.reg = 1;
            jobs{1}.spm.tools.oldnorm.estwrite.roptions.preserve = 0;
            jobs{1}.spm.tools.oldnorm.estwrite.roptions.bb = NaN(2,3);
            jobs{1}.spm.tools.oldnorm.estwrite.roptions.vox = [cfg.MRI.sliceThickEPI cfg.MRI.sliceThickEPI cfg.MRI.sliceThickEPI];
            jobs{1}.spm.tools.oldnorm.estwrite.roptions.interp = 1;
            jobs{1}.spm.tools.oldnorm.estwrite.roptions.wrap = [0 0 0];
            jobs{1}.spm.tools.oldnorm.estwrite.roptions.prefix = 'w0';

          case 'TPM_T1'
            %% inputs: 
            %%    * Deformation Field Image : y_*T1_MPRAGE*.nii
            %%    * Coregistred Structural Image (*T1_MPRAGE*.nii)
            %%    * Realigned EPI Images (ua*.nii)
            %%    * Grey Matter Native: c1*.nii
            %%    * White Matter Native: c2*.nii
            %%    * Cerebrospinal flux Native : c3*.nii
            %% 
            %% outputs:
            %%    * Normalized structural image (w* _anat10.nii)
            %%    * Normalized EPI Images (wua*.nii)
            %%    * Grey Matter Normalized : wc1*.nii
            %%    * White Matter Normalized : wc2*.nii
            %%    * Cerebrospinal flux Normalized : wc3*.nii
            
            %% Get Field Deformation image
            fwdDef = spm_select('FPList', sdirs.T1, '^y_.*nii$'); 
          
            % Get coregistered structural image  
            coregAnat = spm_select('FPList', sdirs.T1, '^msPR.*nii$');  
    
            %% Get tissue maps
            c1 = spm_select('FPList', sdirs.T1, ['^c1.*\.nii$']); 
            c2 = spm_select('FPList', sdirs.T1, ['^c2.*\.nii$']);  
            c3 = spm_select('FPList', sdirs.T1, ['^c3.*\.nii$']);  
            c1c2c3 = cellstr(vertcat(c1, c2, c3));  


            jobs{1}.spm.spatial.normalise.write.subj.def = {fwdDef};
            jobs{1}.spm.spatial.normalise.write.subj.resample = {coregAnat};
            jobs{1}.spm.spatial.normalise.write.woptions.bb = NaN(2,3);  % let SPM figure it out from the data
            jobs{1}.spm.spatial.normalise.write.woptions.vox = [cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1];
            jobs{1}.spm.spatial.normalise.write.woptions.interp = 4;
            jobs{1}.spm.spatial.normalise.write.woptions.prefix = 'w1';
            
            jobs{2}.spm.spatial.normalise.write.subj.def = {fwdDef};
            jobs{2}.spm.spatial.normalise.write.subj.resample = EPIs;
            jobs{2}.spm.spatial.normalise.write.woptions.bb = NaN(2,3);
            jobs{2}.spm.spatial.normalise.write.woptions.vox = [cfg.MRI.sliceThickEPI cfg.MRI.sliceThickEPI cfg.MRI.sliceThickEPI];
            jobs{2}.spm.spatial.normalise.write.woptions.interp = 4;
            jobs{2}.spm.spatial.normalise.write.woptions.prefix = 'w1';
            
            jobs{3}.spm.spatial.normalise.write.subj.def = {fwdDef};
            jobs{3}.spm.spatial.normalise.write.subj.resample = c1c2c3;
            jobs{3}.spm.spatial.normalise.write.woptions.bb = NaN(2,3);
            jobs{3}.spm.spatial.normalise.write.woptions.vox = [cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1];
            jobs{3}.spm.spatial.normalise.write.woptions.interp = 4;
            jobs{3}.spm.spatial.normalise.write.woptions.prefix = 'w1';
            
         case 'TPM_EPI'
            %% inputs/outputs like for T1 but with deformation field and segmentations calc'd from EPI 
           
            
            %% Get Field Deformation image
            fwdDef = spm_select('FPList', sdirs.T1, '^y_.*nii$'); 
          
            % Get coregistered structural image  
            coregAnat = spm_select('FPList', sdirs.T1, '^sPR_.*nii$');  
    
            %% Get tissue maps
            c1 = spm_select('FPList', sdirs.T1, ['^c1.*\.nii$']); 
            c2 = spm_select('FPList', sdirs.T1, ['^c2.*\.nii$']);  
            c3 = spm_select('FPList', sdirs.T1, ['^c3.*\.nii$']);  
            c1c2c3 = cellstr(vertcat(c1, c2, c3));  


            jobs{1}.spm.spatial.normalise.write.subj.def = {fwdDef};
            jobs{1}.spm.spatial.normalise.write.subj.resample = {coregAnat};
            jobs{1}.spm.spatial.normalise.write.woptions.bb = NaN(2,3);  % let SPM figure it out from the data
            jobs{1}.spm.spatial.normalise.write.woptions.vox = [cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1];
            jobs{1}.spm.spatial.normalise.write.woptions.interp = 4;
            jobs{1}.spm.spatial.normalise.write.woptions.prefix = 'w1';
            
            jobs{2}.spm.spatial.normalise.write.subj.def = {fwdDef};
            jobs{2}.spm.spatial.normalise.write.subj.resample = EPIs;
            jobs{2}.spm.spatial.normalise.write.woptions.bb = NaN(2,3);
            jobs{2}.spm.spatial.normalise.write.woptions.vox = [cfg.MRI.sliceThickEPI cfg.MRI.sliceThickEPI cfg.MRI.sliceThickEPI];
            jobs{2}.spm.spatial.normalise.write.woptions.interp = 4;
            jobs{2}.spm.spatial.normalise.write.woptions.prefix = 'w1';
            
            jobs{3}.spm.spatial.normalise.write.subj.def = {fwdDef};
            jobs{3}.spm.spatial.normalise.write.subj.resample = c1c2c3;
            jobs{3}.spm.spatial.normalise.write.woptions.bb = NaN(2,3);
            jobs{3}.spm.spatial.normalise.write.woptions.vox = [cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1 cfg.MRI.sliceThickT1];
            jobs{3}.spm.spatial.normalise.write.woptions.interp = 4;
            jobs{3}.spm.spatial.normalise.write.woptions.prefix = 'w1';

       case 'DARTEL'  
           % DARTEL requires selecting ALL subj WM/GM -- select files now and calc template, then apply norm on data after
       %outside
       %% inputs: DARTEL Template_[0-6], flow fields u_rp*.nii
       %% outputs: 
       %% https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=ind0810&L=spm&P=R53978&1=spm&9=A&I=-3&J=on&d=No+Match%3BMatch%3BMatches&z=4 
       %% John Ashburner says 
       %% DARTEL does not register the images with MNI space, but 
       %%  instead transforms all the data to the average shape of all the individuals.   
       %%
       %% also see
       %% https://www.jiscmail.ac.uk/cgi-bin/wa.exe?A2=spm;75a13f78.1203 

            if do.PREPROC.p09darii_applyNorm_EPI || do.PREPROC.p09darii_applyNorm_T1
                %% INPUTS:
                %%   * flow field urc1*.nii
                %%   * Template_[1-6].nii
                %%   * c1*.nii (and other tissues) 
                %% OUTPUTS:
                %%   * smoothed, normalized swmu2mean*nii
                
                jj     = 0;
                
                if ( cfg.PREPROC.normalize_dartel_grpTempCreate ) 
                    subRef   = sprintf('sub%03d',cfg.PREPROC.normalize_dartel_grpTempSubnr2use);
                    sRefdirs = e3_set_sdirs(cfg.dirs.sub,subRef); 
                   
                    switch cfg.PREPROC.normalize_dartel_srcModality
                        case 'T1'
                            dir_templ = sRefdirs.T1;
                        case 'EPI'
                            dir_templ = fullfile(sRefdirs.gridC, 'run1');
                     end
                else
                    dir_templ = cfg.dirs.VBM;
                end
                
                switch cfg.PREPROC.normalize_dartel_srcModality
                    case 'T1'
                        dir_flow  = sdirs.T1;
                    case 'EPI'
                        dir_flow  = fullfile(sdirs.gridC,'run1');
                end
                    
                     
                templ = spm_select('FPList', dir_templ, '^TemplateEPIra_6.*\.nii$'); % T1: Template_6.nii, EPI: TemplateEPI_6.nii
                flow  = spm_select('FPList', dir_flow, '^u_.*c1.*TemplateEPIra\.nii$'); % T1: urc1*, EPI: uc1

                c1T1    = spm_select('FPList', sdirs.T1, '^c1.*PR.*\.nii$');
                c2T1    = spm_select('FPList', sdirs.T1, '^c2.*PR.*\.nii$');

                mT1   = spm_select('FPList', sdirs.T1, '^msPR.*\.nii$');


                if do.PREPROC.p09darii_applyNorm_T1
                    jj = jj+1;

                    T1s2norm = cellstr(vertcat(cellstr(c1T1), cellstr(c2T1), cellstr(mT1)));

                    jobs{jj}.spm.tools.dartel.mni_norm.vox                 = cfg.MRI.T1.vxSz;
                    jobs{jj}.spm.tools.dartel.mni_norm.bb                  = [NaN NaN NaN
                                                                             NaN NaN NaN];
                    jobs{jj}.spm.tools.dartel.mni_norm.preserve            = 0;%1;
                    jobs{jj}.spm.tools.dartel.mni_norm.fwhm                = [0, 0, 0]; %[cfg.PREPROC.smooth.fwhm cfg.PREPROC.smooth.fwhm cfg.PREPROC.smooth.fwhm]; 
                    jobs{jj}.spm.tools.dartel.mni_norm.template            = {templ};


                    jobs{jj}.spm.tools.dartel.mni_norm.data.subj.flowfield = {flow};
                    jobs{jj}.spm.tools.dartel.mni_norm.data.subj.images    = T1s2norm;
                end

                if do.PREPROC.p09darii_applyNorm_EPI
                    jj = jj + 1;
                    EPIs2norm = cellstr(vertcat(cellstr(meanEPI), cellstr(EPIs)));

                    jobs{jj}.spm.tools.dartel.mni_norm.vox                 = cfg.MRI.EPI.vxSz;
                    jobs{jj}.spm.tools.dartel.mni_norm.bb                  = [NaN NaN NaN
                                                                             NaN NaN NaN];
                    jobs{jj}.spm.tools.dartel.mni_norm.preserve            = 0;
                    jobs{jj}.spm.tools.dartel.mni_norm.fwhm                = [0, 0, 0]; %[cfg.PREPROC.smooth.fwhm cfg.PREPROC.smooth.fwhm cfg.PREPROC.smooth.fwhm];
                    jobs{jj}.spm.tools.dartel.mni_norm.template            = {templ};

                    jobs{jj}.spm.tools.dartel.mni_norm.data.subj.flowfield = {flow};
                    jobs{jj}.spm.tools.dartel.mni_norm.data.subj.images    = EPIs2norm;
                end
            end

       case 'SyN'
           
           
   end
end

   
