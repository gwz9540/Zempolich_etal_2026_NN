%% GUI_JoystickTask_210622

% A few things about this GUI template:
% 1) the code is written in an object-oriented way, meaning that
% properties (o.dir.project) and methods (o.call_button1()) can be
% called from the obj. This means that you do not need to store variables in handles and use GUIData to update the variable handles)
% 2) you can access and modify any property of any element of the GUI via the obj
% 3) click right on any element of the GUI opens the code of the callback function (which is executed when you click left on a button).
% 4) Number of elements of the GUI can be modified programmatically by adding a string to the list of elements (cell variable El). No more opening GUIDE to add a button to your GUI

% Karin Morandell 2018_11_28
% Grant W. Zempolich 2022_7_23
% 2020_03_04 updated acquiring and saving functions

classdef GUI_JoystickTask_210622<handle
    
    properties
        dir; % directory related information
        f; % main gui figure handle
        el; % elements of the GUI
        
        hardware;
        cam; % cameras
        cam_table; % table of camera params
        
        data; % data structures stored there
        audio;
        flag; %
        params; % mainly behavioral parameters
        fig; % other figures handles
        hostname;
        netcom;%relevant to network commands for 2p and ephys
        
    end
    
     methods
        
        function o=GUI_JoystickTask_210622()
            
            dbstop if error
            
            % Modify this
            o.set_rig_specific_param();% modify that
            
            %% Change elements of the GUI (sections and button names)
            El = {};
            El = cat(2,El,{'INPUTS' 'input_encoder' 'input_lick'});
            El = cat(2,El,{'OUTPUTS' 'output_valve' 'output_sound'  'output_LED' 'output_opto'});
            El = cat(2,El,{'DATA' 'OpenGoogleSheet' 'UpdateGoogleSheet' 'ShowData' 'OpenDataFolder' 'SaveData' 'Autosave' });
            El = cat(2,El,{'SOUND' 'WriteSounds'  'ShowSounds'});
            El = cat(2,El,{'VIDEO' 'OpenVidFolder' 'OpenCamViewer' 'SaveVideo' 'ShowCamParams' 'StartCams' 'StopCams'});
            El = cat(2,El,{'PARAMS' 'GetParams' 'ShowParams' 'UpdateParamsHistory' 'SaveParams' 'EditParams' 'SaveParamsAsDefault' 'LoadPrevious' 'LoadDefault' 'InitParams' 'ShowProtocol'});
            El = cat(2,El,{'BEHAVIOR' 'Run' 'Pause' 'TestAOs' 'TestValves' 'TestTones' 'ResetForce' 'ResetCounters'});
            El = cat(2,El,{'GUI' 'NextMouse' 'NextSameMouse'});
            El = cat(2,El,{'ANALYSIS' 'AcrossAnimals' 'ForceLevel' 'RealTimeParams' 'UpdateAnalysis' 'rewards' 'session_duration' 'sound' 'pull' 'push' 'lick' 'percent_rewarded' });
            El = cat(2,El,{'FIGURES' 'PreviousSession' 'RealTimeTracking' 'DispData'  'DispLastTrials' 'MovingPerformance' 'HistTargetDuration' 'Learning' 'DispTrialTypes' 'PlotEncoder' 'HistMovAmp' 'learning_meas_xA'});
            El = cat(2,El,{'msg'});% message box
            
            o.makeGUI(El);
            o.call_ShowParams();
            o.call_LoadDefault();
            o.initialize_hardware();
  
            set(o.el.Autosave,'Value',1)
            o.call_Autosave();
            set(o.el.SaveVideo,'Value',1)
            o.call_SaveVideo();
            o.addmsg('READY!!')
            set(o.el.Run,'Enable','on','style','togglebutton')
            answer = questdlg('Would you like to start the parallel pool now?','Start parallel pool',{'Yes' 'No'});
            
            if answer(1)=='Y'
                    PP=gcp();
            end
        end% opening function
        
        %% *********************************************
        %% makeGUI
        function makeGUI(o,El)
            FontSize = 8;
            TitleFontSize = FontSize+2;
            el_height = FontSize+5;
            el_width_ori = 150;
            msg_height = 140;
            nrows = 2+(find(strcmp(El,'ResetCounters'))+1-find(strcmp(El,'INPUTS')));
            y0coeff = 0.94;
            
            % Create directories
            o.dir.project = fileparts(mfilename('fullpath'));
            o.dir.project = o.dir.project(1:min(find(o.dir.project==filesep,2,'last')));
            F=dbstack;
            o.dir.thisgui = fullfile(o.dir.project,'GUIs',F(1).file(1:end-2));  
            o.params.url = fullfile(o.dir.thisgui ,'params','params_default_210617.mat');
            Sections = El(strcmp(El, upper(El)));
            
            % Make directories if they don't exist
            Fs=fieldnames(o.dir); % folders
            for ifs = 1:numel(Fs)
                if ~isfolder(o.dir.(Fs{ifs}))
                    mkdir(o.dir.(Fs{ifs}))
                end
            end
            addpath(genpath(o.dir.project))
            o.dir.dropbox='C:XXX';
        
            
            % avoid narginchk function error
            try
                rmpath(genpath('C:XXX'))
            end
            
            % Create GUI figure
            o.f = figure('menu','none','Name',mfilename);
            o.f.Color = [0.4940 0.1840 0.5560];
            % Change background color of the figure to match background of
            % matlab window
            o.f.Position = [10 45 350 720];
            % Generate elements of the GUI

            nEl = numel(El);
            nInputButtons =numel(El(startsWith(El, 'input_'))); %
            nOutputButtons =numel(El(startsWith(El, 'output_'))); % provisory
            o.f.Position(4) = nrows*el_height;
            
            y0=o.f.Position(4)*y0coeff;% element vertical position
            x0=10;% element horiontal position

            for iel = 1:nEl
                ele = El{iel};% element name

                % create element of the GUI
                eval(['o.el.' ele '=uicontrol(o.f,''Style''' ',''pushbutton'');'])
                
                % add button specific values
                switch ele
                    case 'INPUTS'
                        el_width = el_width_ori/2;
                    case 'OUTPUTS'
                        y0 = y0+(max([nOutputButtons nInputButtons])+1)*el_height;
                        x0 = o.el.OUTPUTS.Position(1)+el_width;
                    case 'DATA'
                        y0 = o.f.Position(4)*y0coeff+(nOutputButtons+1)*el_height;
                        x0 = 10;
                        el_width = el_width_ori;
                    case 'ANALYSIS'
                        x0 = x0+el_width_ori+10;% second column
                        y0=o.el.OUTPUTS.Position(2)*2.1;% element vertical position is first line
                    case {'Pause' 'Run'}
                        o.el.Pause.Style = 'togglebutton';
                    otherwise
                        
                end                
                set(o.el.(ele),'position',[x0 y0-el_height*iel el_width el_height],'string',ele,'HorizontalAlignment', 'right')
                % define callback function for each element
                % each button can be executed by the following command : o.call_button1();
                str = ['call_' ele];
                eval(['set(o.el.(ele),''callback''' ',@o.' str ')'] );
                
                if strcmp(ele(1:3),'inp')
                    set(o.el.(ele),'style','togglebutton','backgroundcolor','b','ForegroundColor','w')
                elseif strcmp(ele(1:3),'out')
                    set(o.el.(ele),'style','togglebutton','backgroundcolor','k','ForegroundColor','w')
                end
            end
            set(o.el.Run,'Enable','off')
            
            
            % Message box (change message box element position)
            msg_height = 250;
            y0=o.f.Position(4)*0.98+iel*el_height-o.el.(El{iel-1}).Position(2)+msg_height;% element vertical position is first line
            set(o.el.msg,'style', 'text','horizontalalignment','left','backgroundcolor','w','string',{'msg:'})
            o.el.msg.Position(3:4)= [el_width msg_height];
            o.el.msg.Position(2)= o.el.(El{iel-1}).Position(2)-msg_height;
            
            % Section elements (change section elements style to text)
            for iel = 1:numel(Sections)
                set(o.el.(Sections{iel}),'style', 'text','fontsize',TitleFontSize,'horizontalalignment','left','backgroundcolor',o.f.Color)
            end
            

            % Shortcut to code (right click on elements of the
            % GUI will open corresponding code in the function file)
            F = methods(mfilename);
            F=F(strncmp('call_',F,5));
            for i = 1:numel(F)
                try
                    set(o.el.(F{i}(6:end)),'uicontextmenu',uicontextmenu('Callback',@o.FindCodeInThisGUI,'UserData',F{i}))
                end
            end
            
            % Make some button togglebuttons
            listOftogglebuttons = {'SaveVideo' 'Autosave' 'RealTimeTracking' 'Pause' 'AcrossAnimals'};
            for i =1:numel(listOftogglebuttons)
                set(o.el.(listOftogglebuttons{i}),'style','togglebutton','ForegroundColor','w','BackgroundColor','k');
            end
            
            % Make dangerous buttons red
            listOftogglebuttons = {'NextMouse' 'NextSameMouse' };
            for i =1:numel(listOftogglebuttons)
                set(o.el.(listOftogglebuttons{i}),'ForegroundColor','w','BackgroundColor','r','FontWeight','bold');
            end
            
         
            disp('GUI initialized!')
            drawnow;
        end
 
           %% set_rig_specific_param
        function set_rig_specific_param(o)
        % Enter path to data folder
         o.dir.data = fullfile('Z:XXX');
         
        % Enter camera
        o.cam.FrameRate = 30;
        o.cam.port = '1';%
        o.cam.ip = 'XXX';
        o.cam(2).FrameRate = 30;
        o.cam(2).port = '2';%
        o.cam(2).ip = 'XXX';%
        o.cam(3).FrameRate = 30;
        o.cam(3).port = '3';%
        o.cam(3).ip = 'XXX';%
        o.cam(4).FrameRate = 30;
        o.cam(4).port = '4';%
        o.cam(4).ip = 'XXX';%
        end
        
         %% initialize_hardware
        function initialize_hardware(o)
            
            try
                daqreset;
            end
            
            % Set priority of Matlab process to high with Psychotool Box
            % function
            try
                Priority(1);
            catch
                warning('Setting priority of Matlab process to high with Psychotool Box did not work')
            end

         
            try
                o.NI = daq.createSession('ni');
                
                if any(strcmp(D(:,3),'c')) % if counter channel make new session
                    o.NIvalve = daq.createSession('ni');
                end
                
                cntIn = 0;
                cntOut = 0;
                for i = 1:nD
                    disp(D(i,:))
                    switch D{i,3}
                        case 'd'
                            switch D{i,4}% add digital channels
                                case 'i'
                                    ch=o.NI.addDigitalChannel(o.hardware.device,['port' num2str(D{i,1}),filesep,'line' num2str(D{i,2})],'InputOnly');
                                    cntIn =cntIn+1;
                                    ch.Name = D{i,5};
                                    o.hardware.i4.(ch.Name)=cntIn;
                                case 'o'
                                    ch=o.NI.addDigitalChannel(o.hardware.device,['port' num2str(D{i,1}),filesep,'line' num2str(D{i,2})],'OutputOnly');
                                    cntOut =cntOut+1;
                                    ch.Name = D{i,5};
                                    o.hardware.i4.(ch.Name)=cntOut;
                            end
                            
                        case 'a'% add analog channels
                            switch D{i,4}
                                case 'i'
                                    ch=o.NI.addAnalogInputChannel(o.hardware.device,D{i,2},'Voltage');
                                    ch.Name = D{i,5};
                                    cntIn =cntIn+1;
                                    o.hardware.i4.(ch.Name)=cntIn;
                                case 'o'
                                    ch=o.NI.addAnalogOutputChannel(o.hardware.device,D{i,2},'Voltage');
                                    ch.Name = D{i,5};
                                    cntOut =cntOut+1;
                                    o.hardware.i4.(ch.Name)=cntOut;
                            end
                        case 'c' % add counters channels
                            switch D{i,4}
                                case 'i'
                                    
                                    ch=o.NI.addCounterInputChannel(o.hardware.device,['ctr' num2str(D{i,2})],'Position');
                                    cntIn =cntIn+1;
                                    ch.Name = D{i,5};
                                    o.hardware.i4.(ch.Name)=cntIn;                                
                                case 'o'
                                    
                                    ch=o.NIvalve.addCounterOutputChannel(o.hardware.device,['ctr' num2str(D{i,2})],'PulseGeneration');
                                    %                                     cntOut =cntOut+1;
                                    
                                    ch.DutyCycle= 0.999;
                                    ch.Frequency= 1;
                                    ch.InitialDelay= 0;
                                    ch.Name = D{i,5};
                                    o.hardware.i4.(ch.Name)=1;                                    
                                    
                            end
                    end
                end
                
                disp('NI board initialized')
                disp(o.NI);
            catch exception
                warning('No NI board setup')
                
            end
      
            try
                o.initialize_cams();
                disp('Cam initialized!')
            catch
                warning('Cam not initialized!')
            end
            
            
        end
        
        %% initialize_cams
        function initialize_cams(o)
            ncam = numel(o.cam);
            o.hardware.ncam = ncam;
            
            for icam =1:ncam
                try
                    o.cam(icam).cam = ipcam(['http://', o.cam(icam).ip, '/mjpg/', o.cam(icam).port, '/video.mjpg'],'XXX','XXX');
                    
                catch
                    disp 'did not init cam!!!'
                end
                disp(['http://', o.cam(icam).ip, '/mjpg/', o.cam(icam).port, '/video.mjpg']);
                % initialise timestamps for each frame and corresponding
                % behavior filename
                o.cam(icam).timestamps = [nan];
                o.cam(icam).filename = cell(0,1);
                o.cam(icam).filename{1} = ['CAM' num2str(icam) '_NA'];
                
            end
        end
 
        %% call_DATA
        function call_DATA(o,src,ev)
            
        end
        
       
        %% call_OpenDataFolder
        function call_OpenDataFolder(o,src,ev)
            s= o.p2s();
            DIR = fullfile(o.dir.data,'behavior',['m' num2str(s.anm_id)],num2str(s.session_date));
            if ~isdir(DIR)
                mkdir(DIR);
            end
            winopen(DIR);
        end
        
   
        %% call_SaveData
        function call_SaveData(o,src,ev) 
            
            if o.el.SaveVideo.Value==1
                try
                    while o.cam(1).tempcamdata.QueueLength
                        pause(1);
                        disp('waiting for parpoll to finish')
                    end
                end
            end
            
            
            [params,params_options]= o.call_GetParams();
            
            tic
            url = fullfile(o.dir.data,'behavior', ['m' num2str(params.anm_id)],num2str(params.session_date) );
            if isdir(url)==0
                mkdir(url);
            end
            filename = ['m' num2str(params.anm_id) '_' num2str(params.session_date) '_' ];
            
            % get rid of preallocation for analog events
            % make variables to save
            o.data.continuous();
            continuous = o.data.continuous;
            
            possible_continuous = fieldnames(continuous);
            for ifi=2:numel(possible_continuous)
                fi = possible_continuous{ifi};
                cnt = continuous.(fi).cnt;
                fi2 =  fieldnames(continuous.(fi));
                for ifi2 = 1:numel(fi2)
                    try
                        continuous.(fi).(fi2{ifi2})=continuous.(fi).(fi2{ifi2})(1:cnt,:);
                    end
                end
            end
            
            % Save camera details (timestamps, delete parallel pools)
            cam =  o.cam;
            listToDelete = {'preview','tempcamdata','parpool','cam'};
            for i = 1:numel(listToDelete)
                try
                    cam=rmfield(cam,listToDelete{i});
                end
            end
            
            ncam = numel(cam);
            
            try
                for icam = 1:ncam
                    continuous.cam(icam).time = cam(icam).timestamps(:);
                    continuous.cam(icam).time = continuous.cam(icam).time(2:end);
                    continuous.cam(icam).filename = cam(icam).filename(:);
                    continuous.cam(icam).filename = continuous.cam(icam).filename(2:end);
                    continuous.cam(icam).frame_rate = cam(icam).FrameRate;
                    continuous.cam(icam).tbeg = continuous.cam(icam).time(1);
                    continuous.cam(icam).possible_filenames = unique(continuous.cam(icam).filename);
                    continuous.cam(icam).frame_rate_comp = 1/mean(diff(continuous.cam(icam).time));
                    continuous.cam(icam).cnt = cam(icam).cnt;
                    metadata.cam(icam).filename = continuous.cam(icam).filename;
                    metadata.cam(icam).frame_rate_comp = continuous.cam(icam).frame_rate_comp;
                end
                
            end
            
            
            % get rid of preallocation for input and output events
            events = o.data.events;
            possible_events=fieldnames(events);
            n_events = numel(possible_events);
            for iev = 1:n_events
                thisEvent = possible_events{iev};
                fi1 = fieldnames(events.(thisEvent));
                fi1 = fi1(strcmp(fi1,'cnt')==0);
                for ifi=1:numel(fi1)
                    
                    cnt = events.(thisEvent).cnt;
                    try
                        events.(thisEvent).(fi1{ifi})=events.(thisEvent).(fi1{ifi})(1:cnt,:);
                    catch
                        try
                            events.(thisEvent).(fi1{ifi})=events.(thisEvent).(fi1{ifi})(:,1:cnt)';
                        end
                    end
                end
            end
            
            % get rid of preallocation for params history
            params_history = o.data.history.params;
            params_history.data = params_history.data(1:params_history.cnt);
            params_history.time = params_history.time(1:params_history.cnt);
            
            hardware =  o.hardware;% check that KM
            audio = o.audio;
            
            metadata.session_beginning = o.data.session_beginning;
            try
                metadata.session_duration_min = (o.data.timestamp-o.data.session_beginning)/60;
            catch
                metadata.session_duration_min = (GetSecs-o.data.session_beginning)/60;
            end
            metadata.protocol = params.protocol_name;
            
            % save raw data
            tic
            experiment =  o.get_exp_nb(url); % Do not overwrite previous, provisory
            save_url = fullfile(url, ['raw_' filename experiment]);
            if exist(save_url,'file')==0
                save(save_url, 'events','continuous','hardware','params','metadata','params_history','params_options','-v7.3','-nocompression');
                disp(['Saved in ' num2str(toc) ' s as ' [filename experiment]])
            else
                keyboard
            end
            
            % save params in separate file
            o.call_SaveParams();
            
            % save text file with beh_cam protocol name
            try
                camtxt = continuous.cam(1).possible_filenames{1}(end-6:end-4);
            catch
                camtxt = 'NA';
            end
            % Text file container- athena
           
            fn0.txt = sprintf('raw_%s%s_cam%s_prot%s_%dmin_%s_%.0frewards',filename,experiment,camtxt,metadata.protocol,round(metadata.session_duration_min),params.recording_type, o.data.events.valve.cnt);
            url_txt = fullfile(url,[fn0.txt '.txt']);
            fid=fopen(url_txt,'w');
            fprintf(fid,'Filename: %s \n experiment: %s \n length: %d min \n', filename,experiment,round(metadata.session_duration_min));
            fprintf(fid,'Pushes: %d \n Rewards: %d \n Licks including Noise: %d \n', o.data.events.push.cnt, o.data.events.valve.cnt, o.data.events.lick.cnt);
            fprintf(fid,'Opto Trials: %d \n', o.data.events.opto.cnt);
            fclose(fid);
          
%             %% Save ZOOMH5 Audio to separate file
%             url = fullfile(o.dir.data,'audio', ['m' num2str(params.anm_id)],num2str(params.session_date) );
%             if isdir(url)==0
%                 mkdir(url);
%             end
%             
%             filename = ['m' num2str(params.anm_id) '_' num2str(params.session_date) '_' ];
%             save_url = fullfile(url, ['audio_' filename experiment]);
%             if exist(save_url,'file')==0
%                 save(save_url, 'audio','-v7.3');
%                 disp('Saved ZOOM H5 audio!')
%             else
%                 keyboard
%             end
%             % update GoogleSheet
%             %             o.call_UpdateGoogleSheet();
%             disp('saved')
        end
        

        
        
        
        %% call_Autosave
        function call_Autosave(o,src,ev)
            o.el.Autosave.ForegroundColor = [1 1 1];
            o.el.Autosave.BackgroundColor = [o.el.Autosave.Value 0 0];
            
        end
        
        function [a,d,rec,fo,fn0,fn,url,prot]=gce(o)
            % [a,d,rec,fo,fn0,fn,url,prot]=gce(o)
            
            Params = o.call_GetParams();
            a= ['m' num2str(Params.anm_id)];
            d= num2str(Params.session_date);
            
            
            fo.beh = fullfile(o.dir.data,'behavior',a,d);
            rec.beh = o.get_exp_nb(fo.beh); % Do not overwrite previous, provisory
            
            fn0.beh = ['raw_' a '_' d '_' rec.beh];
            fn.beh = [fn0.beh '.mat'];
            url.beh = fullfile(fo.beh,fn.beh);
            prot= Params.protocol_name;
            
            
            
            fo.params = fullfile(o.dir.data,a,d,rec.beh);
            fn0.params = ['params_' a '_' d '_' rec.beh];
            fn.params = [fn0.params '.mat'];
            url.params = fullfile(fo.params,fn.params);
            
            
        end
        
       
        %% DATA RELATED FUNCTIONS
        
        function exp_nb=get_exp_nb(o,varargin)
            %%exp_nb=get_exp_nb(o,varargin)
            % varargin: session folder
            Params = o.p2s();
            if isempty(varargin)
                di = fullfile(o.dir.data,'behavior', ['m' num2str(Params.anm_id)],num2str(Params.session_date) );
            else
                di =varargin{1};
                
            end
            
            % Check data folder and get experiment number
            filename = ['raw_m' num2str(Params.anm_id) '_' num2str(Params.session_date) '_*.mat' ];
            if isfolder(di)==0
                mkdir(di)
            end
            list=dir(fullfile(di,filename));
            exp_nb = numel(list)+1;
            exp_nb = num2str(exp_nb,'%03.0f');
            % add line to avoid double saving
        end
        
        function exp_nb=get_params_exp_nb(o,di)
            s = o.p2s();
            % Check data folder and get experiment number
            filename = ['params_m' num2str(s.anm_id) '_' num2str(s.session_date) '_*' ];
            if isfolder(di)==0
                mkdir(di)
            end
            list=dir(fullfile(di,filename));
            exp_nb = numel(list)+1;
            exp_nb = num2str(exp_nb,'%03.0f');
            % add line to avoid double saving
        end
        
        
        %% call_VIDEO
        function call_VIDEO(o,src,ev)

        end        
     
        %% call_OpenVidFolder
        function call_OpenVidFolder(o,src,ev)
            s = o.p2s();
            DIR = fullfile(o.dir.data,'videos',['m' num2str(s.anm_id)],num2str(s.session_date));
            if ~isdir(DIR)
                mkdir(DIR);
            end
            winopen(DIR);
        end
        
        %% call_OpenCamViewer
        function call_OpenCamViewer(o,src,ev)
            
            ncam = numel(o.cam);
            
            for icam =1:ncam
                
                url = ['http://', o.cam(icam).ip, '/mjpg/', o.cam(icam).port, '/video.mjpg'];
                %                         dos(['"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --chrome-frame --window-size=100,100 --window-position=0,0 "' url '"'])
                dos(['start chrome --chrome-frame --new-window --window-size=300,200 --profile-directory="Default" --notoolbar --force-device-scale-factor=0.20 --window-position=1,1  --app= "' url '"']);
                
            end
        end
        
        
        
        %% call_SaveVideo
        function call_SaveVideo(o,src,ev)
            o.el.SaveVideo.BackgroundColor = [o.el.SaveVideo.Value 0 0];
        end
        
        %% call_ShowCamParams
        function call_ShowCamParams(o,src,ev)
            try
                close(findobj('name','cam_params'));
            end
            cam = o.cam;
            for icam =1:numel(cam)
                try
                    cam(icam).filenames = char(unique(cam(icam).filename)) ;
                end
            end
            % remove fields
            fn = fieldnames(cam);
            remfi = {'timestamps','t','f','filename', 'filenames' 'el' 'cam' 'tempcamdata' 'parpool'};
            remfi = intersect(remfi,fn);
            for i = 1:numel(remfi)
                
                cam = rmfield(cam,remfi{i});
            end
            fn = fieldnames(cam);
            cam = permute(struct2cell(cam),[3 1 2]);
            ncam = size(cam,1);
            
            f= figure('name','cam_params','position',[sum(o.f.Position([1 3]))  ,0.7*sum(o.f.Position([2 4]))  ,o.f.Position(3) o.f.Position(4)*1.01],'toolbar','none','menu','none');
            f.Position(1)=sum(o.f.Position([1 3]));
            
            t= uitable(f,'Data',[cam num2cell(false(ncam,1))],'Position',[5 30 o.f.Position(3)*0.99 700]);
            set(t,'columnname',[fn; {'select'}],'columnwidth',{80 40, 100,100,50},...
                'ColumnEditable', true,'Tag','camtab');
            
            
            % Set width and height
            f.Position(3) = t.Extent(3)+30;
            f.Position(4) = t.Extent(4)+50;
            t.Position(3) = t.Extent(3)+10;
            t.Position(4) = max([f.Position(4)-30 t.Extent(4)+15]);
            
            % Add buttons
            buttons = {'add_cam' 'delete_cam' 'show_cam'};
            nbut= numel(buttons);
            xo = 5;
            offset = 5;
            for ibut = 1:nbut
                w= 8*numel(buttons{ibut});
                el.(buttons{ibut})=uicontrol(f,'style','pushbutton','callback',@o.camcall,'string',buttons{ibut}...
                    ,'position',[ xo 5 w 20]);
                xo = xo+w+offset;
            end
            set(t,'CellEditCallback',@o.camparamupdate)
            o.cam_table.t = t;
        end
        
        function camparamupdate(o,src,ev)
            icam = ev.Indices(1);
            ifi = ev.Indices(2);
            modifField = src.ColumnName{ifi};
            if ~strcmp(modifField,'select')
                
                newValue = src.Data{icam,ifi};
                o.cam(icam).(modifField)= newValue;
                o.initialize_cams();
                disp(sprintf('updated cam value'))
            end
        end
        
        function camcall(o,src,ev)
            t = o.cam_table.t;
            iselect = find(cell2mat(t.Data(:,end)));
            if isempty(iselect)
                return;
            end
            switch src.String
                case 'show_cam'
                    for icam = iselect(:)'
                        try
                            o.cam(icam).cam = ipcam(['http://', o.cam(icam).ip, '/mjpg/', o.cam(icam).port, '/video.mjpg'],'XXX','XXX');
                        end
                        
                        url = ['http://', o.cam(icam).ip, '/mjpg/', o.cam(icam).port, '/video.mjpg'];
                        %                         dos(['"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --chrome-frame --window-size=100,100 --window-position=0,0 "' url '"'])
                        dos(['start chrome --chrome-frame --new-window --window-size=300,200 --profile-directory="Default" --force-device-scale-factor=0.20 --window-position=1,1  --app= "' url '"']);
                    end
                case 'delete_cam'
                    disp('coming')
                case 'add_cam'
                    disp('coming')
            end
        end
        
        %% call_StartCams
        function call_StartCams(o,src,ev)
            StartNCam;
            
        end
        
        %% call_StopCams
        function call_StopCams(o,src,ev)
            StopNCam;
            
        end
        %% call_PARAMS
        function call_PARAMS(o,src,ev)
            
            
        end
        
        %% call_GetParams
        function [Params,opt,fields,i4]=call_GetParams(o,src,ev)
            % [Params,opt,fields,i4]=call_GetParams(o). Use call_GetParams to transform params cell to 2 structures: params (containing selected value per field) and opt (containing options displayed in param table)
            % takes 20 msec
            
            p = o.params.t.Data;
            fields = p(:,1);
            nrow = numel(fields);
            for irow=1:nrow%ii=13
                val = p{irow,2};
                options =strsplit(p{irow,3},';');
                field= fields{irow,1};
                Double = str2double(val);
                if ~isnan(Double)% if numeric values
                    
                    Params.(field) = Double;
                    opt.(field) = cell2mat(cellfun(@(x) str2double(x),options,'uniformoutput',false));
                else
                    Params.(field) = val;
                    opt.(field) = options;
                end
                
                i4.(field) = irow;
            end
            
            
            
        end
        
        
        %% call_ShowParams
        function call_ShowParams(o,varargin)
            
            
            if numel(varargin)>0
                if strcmp(class(varargin{1}),'matlab.ui.control.UIControl')
                    params = o.params.t.Data;
                else
                    params=varargin{1};
                end
            else
                load(o.params.url,'params')
            end
            try
                close(o.params.f);
            end
            
            RowNames =params(:,1);
            
            o.params.f= figure('name','params','position',[sum(o.f.Position([1 3])),o.f.Position(2),o.f.Position(3) o.f.Position(4)*1.01],'toolbar','none','menu','none');
            o.params.f.Position(1)=sum(o.f.Position([1 3]));
            
            o.params.t= uitable(o.params.f,'Data',params,'Position',[10 30 o.f.Position(3)*0.99 700]);
            set(o.params.t,'columnname',{'param' ,'value','options','menu',' '},'columnwidth',{110, 70,110,80,20});
            set(o.params.t,'ColumnEditable', [false  true true true true],'ColumnFormat', {'char',[],[],{'option1' 'option2'},'logical'})
            set(o.params.t,'Tag','tab','Data',params);
            set(o.params.t,'CellEditCallback',@o.editTable);
            
            % --- Color rows
            C= o.params.t.BackgroundColor;
            C = repmat(C,ceil(size(params,1)/size(C,1)),1);
            i4 = find(cellfun(@(x) contains(x,'threshold'),params(:,1)));
            C(i4,:) = repmat([0 1 1],[size(i4),1]);
            i4 = find(cellfun(@(x) endsWith(x,'ms'),params(:,1)));
            C(i4,:) = repmat([0.112 0.733 0.887],[size(i4),1]);
            i4 = find(cellfun(@(x) endsWith(x,'_s'),params(:,1)));
            C(i4,:) = repmat([0.112 0.733 0.887],[size(i4),1]);
            
            i4 = find(cellfun(@(x) endsWith(x,'kHz'),params(:,1)));
            C(i4,:) = repmat([0.948 1 0.452],[size(i4),1]);
            i4 = find(cellfun(@(x) startsWith(x,'force'),params(:,1)));
            C(i4,:) = repmat([0.667 0.98 0.733],[size(i4),1]);            
            i4 = find(cellfun(@(x) contains(x,'target'),params(:,1)));
            C(i4,:) = repmat([0.7 0.5 0.7],[size(i4),1]);   
            i4 = find(cellfun(@(x) contains(x,'sound_standard_dB'),params(:,1)));
            C(i4,:) = repmat([1 0 0],[size(i4),1]);
            
            i4 = find(ismember(params(:,1),{'anm_id' 'session_date' 'timestamp' 'protocol_name' 'param_type' 'recording_type'}));
            C(i4,:) = repmat(o.f.Color,[size(i4),1]);
            set(o.params.t,'BackgroundColor',C);
            try
            i4 = find(ismember(params(:,1),{'pba_coupling' 'pba_oddball' 'pba_oddball_type' 'sound_categories'}));
            C(i4,:) = repmat([1 0.5 1],[size(i4),1]);
            set(o.params.t,'BackgroundColor',C);            
            end
            
            i4 = strcmp(params(:,1),'sound_standard_ms');
            C(i4,:) = repmat([1 0.2 0.2],[sum(i4),1]);
            i4 = strcmp(params(:,1),'sound_standard_kHz');
            C(i4,:) = repmat([1 0.2 0.2],[sum(i4),1]);
            i4 = strcmp(params(:,1),'sound_standard_ms');
            C(i4,:) = repmat([1 0.2 0.2],[sum(i4),1]);            
            
            % Set width and height
            
            o.params.f.Position(3) = o.params.t.Extent(3)+30;
            o.params.f.Position(4) = o.params.t.Extent(4)+50;
            o.params.t.Position(3) = o.params.t.Extent(3)+10;
            o.params.t.Position(4) = max([o.params.f.Position(4)-30 o.params.t.Extent(4)+10]);
            
            % add row names to i4
            for ifi = 1:numel(RowNames)
                o.params.i4.(RowNames{ifi}) = ifi;
            end
            
            % Add buttons
            buttons = {'add_row_below' 'delete_row' 'plot_protocol' 'edit_params' 'up' 'down'};
            nbut= numel(buttons);
            xo = 5;
            offset = 5;
            for ibut = 1:nbut
                w= 8*numel(buttons{ibut});
                o.params.el.(buttons{ibut})=uicontrol(o.params.f,'style','pushbutton','callback',@o.paramcall,'string',buttons{ibut}...
                    ,'position',[ xo 5 w 20]);
                xo = xo+w+offset;
            end
            

        end
        
        function paramcall(o,src,ev)
            t = o.params.t;
            iselect = find(cell2mat(t.Data(:,end)),1);
            if isempty(iselect)
                return;
            end
            switch src.String
                case 'add_row_below'
                    datBef = t.Data(1:iselect,:);
                    datAft = t.Data(iselect+1:end,:);
                    datNew = inputdlg({'param name','param value','param options (separated by ;)'},'add new param',1,{'param_type','sounds','beh;sounds'});
                    if isempty(datNew)
                        return;
                    end
                    datNew = horzcat(datNew',{[]},{false});
                    t.Data =vertcat(datBef,datNew,datAft);
                    
                case 'delete_row'
                    t.Data(iselect,:) =[];
                case 'plot_protocol'
                    
                    plot_protocol_200625;
                    
                case 'edit_params'
                    set(o.params.t,'ColumnEditable', true )
                    o.addmsg('Param editable');
                case {'up' 'down'}
                    
                    datSelect = t.Data(iselect,:);
                    switch src.String
                        case 'up'
                            datBef = t.Data(iselect-1,:);
                            t.Data(iselect-1,:) = datSelect;
                            t.Data(iselect,:) = datBef;
                        case 'down'
                            datAft = t.Data(iselect+1,:);
                            t.Data(iselect+1,:) = datSelect;
                            t.Data(iselect,:) = datAft;
                    end
                    
            end
            
            % resize width and height
            o.params.f.Position(4) = o.params.t.Extent(4)+50;
            o.params.t.Position(4) = max([o.params.f.Position(4)*.95 o.params.t.Extent(4)+10]);
            
            % add row names to i4
            RowNames = t.Data(:,1);
            for ifi = 1:numel(RowNames)
                o.params.i4.(RowNames{ifi}) = ifi;
            end
        end
        
        
        %% call_UpdateParamsHistory
        function call_UpdateParamsHistory(o,src,ev)
            % if run is pressed, a copy of the params is saved to the
            % history and the count is increase
            
            
            % update timestamp in o.params.t.Data
            if o.el.Run.Value % log params change into data.history
                try
                    now_time = GetSecs;
                catch
                    now_time = 0;
                    disp('Debugging mode')
                end
                
                % update timestamp on params table
                o.params.t.Data{strcmp(o.params.t.Data(:,1),'timestamp'),2}=num2str(now_time);
                o.data.history.params.cnt = o.data.history.params.cnt+1;
                
                % get structure version of param and store it in param
                % history
                
                o.data.history.params.data{o.data.history.params.cnt}=o.params.t.Data;
                o.data.history.params.time(o.data.history.params.cnt)=now_time;
                disp('Changes of params saved in history.');
            end
            
        end
        
        
        
        function editTable(o,src_table,ev)
            src_table.Data(:,5)={false};
            src_table.Data{ev.Indices(1),5}=true;
            
            switch ev.Indices(2)
                case 5 % checkbox = modify dropdown menu
                    table = get(src_table,'Data');
                    if isempty(table{ev.Indices(1),3})
                        disp('No options to choose from')
                        return;
                    end
                    options = strsplit(table{ev.Indices(1),3},';');
                    set(src_table,'ColumnFormat', {'char',[],[],options,'logical'});
                    
                case 4
                    src_table.Data{ev.Indices(1),2} = ev.NewData;
            end
            
            % This update will keep te while params variables up to date
            o.call_UpdateParamsHistory();
        end
        
        

        
        %% call_SaveParams
        function call_SaveParams(o,src,ev)
            Params=o.call_GetParams();
            try
                di = fullfile(o.dir.data,'behavior',['m' num2str(Params.anm_id)], num2str(Params.session_date));
                url = fullfile(o.dir.data,'behavior',['m' num2str(Params.anm_id)], num2str(Params.session_date),['params_' 'm' num2str(Params.anm_id) '_' num2str(Params.session_date) '_' o.get_params_exp_nb(di) '.mat']);
                params = o.params.t.Data(:,1:3);
                save(url,'params');
                o.addmsg('Saved param of the day');
            catch
                disp('did not save params')
            end
        end
        
        %% call_EditParams
        function call_EditParams(o,src,ev)
          set(o.params.t,'ColumnEditable', [true  true true true true])
                o.addmsg('Param editable');
        end        
        
        %% call_SaveParamsAsDefault
        function call_SaveParamsAsDefault(o,src,ev)
            if strcmp(o.params.t.Data{o.params.i4.param_type,2},'beh')
                params = o.params.t.Data(:,1:3);% openvar('params')
                save(o.params.url,'params');
                o.addmsg('Saved default param');
                o.call_LoadDefault();
            else
                disp('param_type is not "beh". Did not overwrite behavior default params.')
            end
        end
        
        
      
        
        %% call_LoadDefault
        function call_LoadDefault(o,src,ev)
            
            try
                load(o.params.url);
            catch
                error('Put params_default.mat in gui params folder.')
            end
            fields = params(:,1);
            params(strcmp(fields,'session_date'),2)= {datestr(now(),'YYmmDD')};
            o.call_ShowParams(params);
            o.addmsg('Loaded default param');
        end
        
        function [Params,opt,fi]=p2s(o)
            % [s,opt,fi]=p2s(o). Use p2s to transform params cell to 2 structures: s (containing selected value per field) and opt (containing options displayed in param table)
            % takes 20 msec
            
            p = o.params.t.Data;
            fields = p(:,1);
            nrow = numel(fields);
            for irow=1:nrow%ii=13
                val = p{irow,2};
                options =strsplit(p{irow,3},';');
                field= fields{irow,1};
                Double = str2double(val);
                if ~isnan(Double)% if numeric values
                    
                    Params.(field) = Double;
                    opt.(field) = cell2mat(cellfun(@(x) str2double(x),options,'uniformoutput',false));
                else
                    Params.(field) = val;
                    opt.(field) = options;
                end
                
                fi.(field) = irow;
            end
            
            
        end
        
        %% call_InitParams
        function call_InitParams(o,src,ev)
            
            if ~isfield(o.data,'history')
                nhis = 500;
                o.data.history.params.data=cell(nhis,1);
                o.data.history.params.time=nan(nhis,1);
                o.data.history.params.cnt = 0;
            end
        end
       
        
        %% call_ShowProtocol
        function call_ShowProtocol(o,src,ev)
            Params = o.call_GetParams();
            BaseFolder = fullfile(o.dir.thisgui,'protocols');
            protocol = Params.protocol_name;
            
            list = dir(fullfile(BaseFolder,['protocol_' protocol '*']));
            % FIXCODE
            if isempty(list)
                warning('no protocol with that name')
            end
            url = fullfile(BaseFolder,list(end).name);
            edit(url)
            
        end
        
        

        %% --------------------------------
        %% call_BEHAVIOR
        function call_BEHAVIOR(o,src,ev)
         
        end
        
        
        
        %% %% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        function initialize_session_beginning(o,src,ev)
            if ~isfield(o.data,'session_beginning')
                o.data.session_beginning = 0;
            end
            if o.data.session_beginning == 0
                try
                    o.data.session_beginning = GetSecs;
                catch
                    warning('Emulator mode: o.data.session_beginning = 0')
                    o.data.session_beginning = 0;
                end
            end
            
            try
                if isnan(Params.force_baseline)
                    o.call_ResetForce();
                end
            end
        end
        
        %% call_Run
        function call_Run(o,src,ev)
            drawnow;
            [Params,opt]=o.p2s();
            if o.el.Run.Value==1
                o.el.Run.BackgroundColor = [1 0 0];
                o.el.Run.String = ['Running...' Params.protocol_name];
                o.addmsg(['Running ' Params.protocol_name]);
                
                % initialize stuff
                o.initialize_session_beginning();
                o.call_InitParams(); % initialise params history if not already done
                o.call_UpdateParamsHistory();%save a first version of the params in o.data.history.params
                
        
                
            else
                o.el.Run.BackgroundColor = [0 1 0];
                o.el.Run.String = 'Run';
                o.addmsg(['Stopped ' Params.protocol_name]);
                try
                    outputSingleScan(o.NI,  zeros(1,o.hardware.nDO));%
                    pause(0.001);
                    stop(o.NI);
                end
                
            end
            
            if o.el.Run.Value==1
            switch Params.protocol_name
                
                
                case 'PassRhythm'
                    protocol_PassRhythm_200624;
                case  'LeversoundLick'
                    protocol_LeversoundLick_190601
                    
                    
                case 'PoFqMap'
                                    
                    protocol_New_Arduino_Code_01_23_23 % PROTOCOL USED IN ZEMPOLICH. ET AL., 2026

                case {'JoystickWN' 'PassJoystick'}
                      protocol_JoystickWN_200304z
                case 'PassReplay'
                    o.sounds.i4wave=1;
                    o.call_WriteSounds();                    
%                     protocol_passive_replay_191215;
                    protocol_passive_replay_200316;      
                    otherwise
                        % find protocol in protocols folder
                        allprotocols = dir(fullfile(o.dir.thisgui,'protocols',['protocol_' Params.protocol_name '*.m']));
                        allprotocols=allprotocols(end).name;
                        if isempty(allprotocols)==0
                            run(allprotocols);
                        else
                            o.addmsg('No protocol found in protocols folder.');
                        end
                end
                
            end
        end

        
        
        %% call_Pause
        function call_Pause(o,src,ev)
            
            
        end
        

        
        %% call_ResetCounters
        function call_ResetCounters(o,src,ev)
            
            resetCounters(o.NI);
            disp('resetCounters')
            
        end
        

        % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% call_GUI
        function call_GUI(o,src,ev)
            
            
            
        end
      
        
     
          
        
        %% call_RealTimeParams
        function call_RealTimeParams(o,src,ev)
            set(o.el.RealTimeParams,'Style','togglebutton')
            if o.el.RealTimeParams.Value
                o.el.RealTimeParams.BackgroundColor =[0 1 0];
            else
                o.el.RealTimeParams.BackgroundColor =[1 1 1];
            end
        end
        
        %% call_RealTimeTracking
        function call_RealTimeTracking(o,src,ev)
            o.el.RealTimeTracking.ForegroundColor = [1 1 1];
            o.el.RealTimeTracking.BackgroundColor = [o.el.RealTimeTracking.Value 0 0];            
        end              
        
        %% call_session_duration
        function call_session_duration(o,src,ev)
            
        end

                
                
%                 % FUNCTIONS
%             catch err
%                 disp(err.stack(1))
%                 disp(err.message)
%             end
%             
            
            function events=FixMissingField_amp_max(url) % FIX
                
                %load params, events and continuous
                load(url,'params','events','continuous');
                mov = events.(params.mov_type);
                mov.amp_max = nan(mov.cnt,1);
                enc = continuous.encoder;
                
                % for each trial
                for itr = 1:mov.cnt
                    i4 = enc.time>=mov.time(itr) & enc.time<=mov.time_end(itr);
                    trial_enc = enc.values(i4); 
                    mov.amp_max(itr)=nanmax(trial_enc);
                end
                events.(params.mov_type)=mov;
                
                % !!!!!!! This line overwrites the raw data. Make sure
                % events is correct before running!!
                save(url,'-append','events')

                
            end
            
            function events = FixMissingField_event_encoder(url)
                %load params, events and continuous
                load(url,'params','events','continuous');
                mov = events.(params.mov_type);
                enc = continuous.encoder;
                
                interp_period = 0.002;
                enc.time_interp = enc.time(1):interp_period:enc.time(end);
                enc.values_interp = interp1(enc.time,enc.values,enc.time_interp);
                trial_window_s =[-1 2];
                trial_time = trial_window_s(1):interp_period:trial_window_s(2);
                nsamp= numel(trial_time);
                
                % prealloc
                mov.encoder = nan(mov.cnt,nsamp);
                mov.time_encoder = repmat(trial_time,mov.cnt,1);
                % for each trial
                for itr = 1:mov.cnt
                    i4 = enc.time>=mov.time(itr)-trial_window_s(1) & enc.time<=mov.time(itr)+trial_window_s(2);
                    trial_enc = enc.values(i4); 
                    mov.encoder(itr,1:min([numel(trial_enc) nsamp]))=trial_enc(:)';
                end
                events.(params.mov_type)=mov;
                continuous.encoder = enc;
                
                % !!!!!!! This line overwrites the raw data. Make sure
                % events and continuous are correct before running!!
                save(url,'-append','events','continuous')                
                
            end
            
            
            function events = FixMissingField_ITIrespect(url)
                
               
                
            end
        
        %% call_msg
        function call_msg(o,~,ev)
            
        end
        
        
        % GUI FUNCTIONS
        %% function addmsg(o,txt)
        % Adds message to message box with timestamp
        function addmsg(o,txt)
            
            o.el.msg.FontName = 'FixedWidth';
            o.el.msg.FontUnits = 'pixels';
            % msg box params
            fz= o.el.msg.FontSize;
            LineHeight= 1.3*ceil(fz);
            nlimax = round(o.el.msg.Position(4)/LineHeight);
            nchmax = floor(1.45*o.el.msg.Position(3)/fz);
            
            % text params
            prevtxt = o.el.msg.String;
            newtxt = {[datestr(now,'HH:MM:SS') ': ' txt]};
            nchnew = numel(newtxt{1});
            nlinew =  ceil(nchnew/nchmax);
            
            
            newtxtc = cell(nlinew,1);
            for ili = 1:nlinew
                if ili<nlinew
                    newtxtc{ili} = newtxt{1}((1:nchmax)+(ili-1)*nchmax);
                else
                    newtxtc{ili} = newtxt{1}((ili-1)*nchmax+1:nchnew);
                end
            end
            
            cattxt = vertcat(prevtxt,newtxtc);
            ncattxt = numel(cattxt);
            ind = max([1 ncattxt-nlimax+1 ]);
            o.el.msg.String = cattxt(ind:end);
            
        end
        
        %% FindCodeInThisGUI(o,src,ev)
        % This function executes when you right click on any element of the GUI and opens the corresponding code.
        function FindCodeInThisGUI(o,src,~)
            F=dbstack;
            finame = F(1).file;
            FindCode(o,finame,src);
        end
        
        %% UpdateGUI(o,src,ev)
        function UpdateThisGUI(o)
            F=dbstack;
            finame = F(1).file;
            UpdateGUI(o,finame);
        end
        

    end% methods
    
end% o