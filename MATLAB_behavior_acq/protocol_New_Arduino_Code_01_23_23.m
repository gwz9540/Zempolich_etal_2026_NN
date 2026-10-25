%% protocol_New_Arduino_Code_01_23_23
% options
Option_DispTICTOC =0;% display option

% Author: Grant W. Zempolich 
% Last updated: 2024-10-12
%% StartCam script initialises camera parallel pools
drawnow;
if o.el.Run.Value==1 && o.el.SaveVideo.Value==1
    o.el.Run.Enable ='off';
    StartNCam;
    o.el.Run.Enable ='on';
    
end

[Params,optParams,fields,i4par]=o.call_GetParams();

%% initialize events
movementType = Params.mov_type;
eventNames = {'home' movementType 'target' 'toneIN' 'toneOUT' 'targetOUT' 'alignPulse' 'alignNegativePE' 'tuningTones' 'sound' 'valve' 'lick'  'opto'};
inputEventNames = {'lick'};
nInputEvents = numel(inputEventNames);

nPrealloc = 10^6;
minimumFieldsPerEvent = {'time','cnt'};
o.data.events = struct();
for iev  = 1:numel(eventNames)
    for ifi = 1:numel(minimumFieldsPerEvent)
        if strcmp(minimumFieldsPerEvent{ifi},'cnt')
            o.data.events.(eventNames{iev}).(minimumFieldsPerEvent{ifi})=0;
        else
            o.data.events.(eventNames{iev}).(minimumFieldsPerEvent{ifi})=nan(nPrealloc,1);
        end
    end
end

% MATLAB Code for initializing Serial Communication between ARDUINO WRITE device and MATLAB
arduinoWrite = serial('COM5','BAUD',57600); % Arduino used for sending commands to control things like LEDs, solenoid etc. Use command fprintf(arduinoWrite,i) to send numbers and letters
fopen(arduinoWrite); % Open active communication channel
% Use function fprintf(arduinoWrite,number) to communicate with ArduinoWrite
% PIN List, what to send via serial to activate various PINs
% 1 = Tone IN PIN;
% 2 = Tone OUT PIN;
% 3 = Alignment PIN HIGH;
% 4 = Alignment PIN LOW;
% 5 = Reward LED PIN HIGH;
% 6 = Reward LED PIN LOW;
% 7 = Zone IN LED PIN HIGH;
% 8 = Zone IN LED PIN LOW;
% 15 = Zone OUT LED PIN HIGH;
% 16 = Zone OUT LED PIN LOW;
% 11 = Laser ON;
% 12 = Laser OFF;
% 13 = Solenoid Valve PIN HIGH;
% 14 = Solenoid Valve PIN LOW;
% 17 = Tone Out Alignment PIN HIGH;
% 18 = Tone Out Alignment PIN LOW;
% 19 = Home IN Alignment PIN HIGH;
% 20 = Home IN Alignment PIN LOW;

% Initialize ARDUINO READ (DAQ-LIKE) Device with this command, establishes connection on COM4 USB port and configures pins to read out sensor data like encoder and lick port etc.
arduinoRead1 = serial('COM4','BAUD',57600,'Terminator',';'); %ENCODER AND LICK VOLTAGE
fopen(arduinoRead1);
%% Wait for serial to initialize and not send problematic outputs
% should sent a 'start' string once ready
serialInit = 0;
disp('Initializing serial')
while serialInit == 0
    arduinoStr = fgets(arduinoRead1);
    %disp(arduinoStr)
    if strfind(arduinoStr, 'Can start code;')
        disp('Serial initialized, can start code')
        serialInit = 1;
    end
end

% initializing event specific fields
o.data.events.(movementType).time_end = nan(nPrealloc,1);
% o.data.events.(movementType).soundseq_kHz= [Params.soundseq_kHz; cell(nPrealloc-1,1)];
% o.data.events.(movementType).soundseq_dB=  [Params.soundseq_dB; cell(nPrealloc-1,1)];
% o.data.events.(movementType).soundseq_thresholds=  [Params.soundseq_thresholds; cell(nPrealloc-1,1)];
o.data.events.(movementType).trial_type=[{'expected'}; cell(nPrealloc-1,1)];
o.data.events.(movementType).rewarded =  nan(nPrealloc,1);
o.data.events.(movementType).time_reward_s=  nan(nPrealloc,1);
o.data.events.(movementType).opto_trial = nan(nPrealloc,1);
o.data.events.(movementType).opto_time=  nan(nPrealloc,1);
o.data.events.(movementType).opto_time_end=  nan(nPrealloc,1);
o.data.events.(movementType).ITI_respect = nan(nPrealloc,1);
o.data.events.(movementType).amp_max = nan(nPrealloc,1);
% o.data.events.(movementType).target_thresholds = cell(nPrealloc,1);

% Initialize Trial Threshold Vector
trialN = Params.totalN_trials; % Total number of trials to be given
blockSize = Params.trial_block_size; %% Change for how many trials in a single 'block'
trial_thresholds = str2double(strsplit(optParams.soundseq_thresholds{1},'/'));
thresh1 = trial_thresholds(1);
thresh2 = trial_thresholds(2);
thresh3 = trial_thresholds(3);
% thresh4 = trial_thresholds(4);
trainN = trialN/blockSize;

o.data.events.(movementType).ThresholdVector = zeros(blockSize,trainN);
o.data.events.(movementType).endZone_ThresholdVector = zeros(blockSize,trainN);

% Catch Trial
o.data.events.(movementType).catch_trial = [0;nan(nPrealloc-1,1)];

% o.data.events.(movementType).opto_delay = nan(nPrealloc,1);
% o.data.events.(movementType).opto_trial_type = repmat({'NA'},nPrealloc,1);

o.data.events.target.time = nan(nPrealloc,1);
o.data.events.target.time_end = nan(nPrealloc,1);
o.data.events.targetOUT.time = nan(nPrealloc,1);

% log Tones
o.data.events.toneIN.time = nan(10000,1);
o.data.events.toneOUT.time = nan(10000,1);
o.data.events.alignPulse.time = nan(10000,1);
o.data.events.alignNegativePE.time = nan(10000,1);
o.data.events.tuningTones.time = nan(1000,1);
o.data.events.tuningTones.cnt = nan(1000,1);
o.data.events.tuningTones.value = nan(1000,1);

o.data.events.sound.time_end = nan(nPrealloc,1);

o.data.events.lick.time_end= nan(nPrealloc,1);

%opto
o.data.events.opto.time = nan(nPrealloc,1);
o.data.events.opto.time_end = nan(nPrealloc,1);
o.data.events.opto.trial_type = nan(nPrealloc,1);
o.data.events.opto.opto_delay = nan(nPrealloc,1);
o.data.events.opto.opto_trial = nan(nPrealloc,1);
    
% event related variables
events = fieldnames(o.data.events);

if Params.Ephys_Recording_Day == 0
    
    for i = numel(trial_thresholds):numel(trial_thresholds):trainN
        
        r = datasample(trial_thresholds,length(trial_thresholds),'Replace',false);
        o.data.events.(movementType).ThresholdVector(:,i) = repmat(r(1),blockSize,1);
        endZone_R1 = r(1) + Params.zone_Size;
        o.data.events.(movementType).endZone_ThresholdVector(:,i) = repmat(endZone_R1,blockSize,1);
        o.data.events.(movementType).ThresholdVector(:,i-1) = repmat(r(2),blockSize,1);
        endZone_R2 = r(2) + Params.zone_Size;
        o.data.events.(movementType).endZone_ThresholdVector(:,i-1) = repmat(endZone_R2,blockSize,1);
        o.data.events.(movementType).ThresholdVector(:,i-2) = repmat(r(3),blockSize,1);
        endZone_R3 = r(3) + Params.zone_Size;
        o.data.events.(movementType).endZone_ThresholdVector(:,i-2) = repmat(endZone_R3,blockSize,1);
        
    end
    
    
elseif Params.Ephys_Recording_Day == 1
    
    ephysDayThresholdVector = [2 1 3 1 3 2 3 1 2 3 2 1 3 1 2 1 2 3 2 3 1 2 1 3 2 3 1 2 1 3 1 3 2 3 2 1 2 3 1 3 1 2];
    
    for i = 1:trainN
        
        r = trial_thresholds(ephysDayThresholdVector(i));
        o.data.events.(movementType).ThresholdVector(:,i) = repmat(r,blockSize,1);
        endZone_R = r + Params.zone_Size;
        o.data.events.(movementType).endZone_ThresholdVector(:,i) = repmat(endZone_R,blockSize,1);
        
        
    end
    
elseif Params.Ephys_Recording_Day == 2
    
    ephysDayThresholdVector = [2 1 3 1 3 2 3 2 1 1 3 2 3 2 1 2 1 3 2 3 1 2 1 3 3 1 2 2 1 3 1 3 2 3 2 1 2 3 1 3 1 2];
    
    for i = 1:trainN
        
        r = trial_thresholds(ephysDayThresholdVector(i));
        o.data.events.(movementType).ThresholdVector(:,i) = repmat(r,blockSize,1);
        endZone_R = r + Params.zone_Size;
        o.data.events.(movementType).endZone_ThresholdVector(:,i) = repmat(endZone_R,blockSize,1);
        
        
    end
    
end

if Params.Opto_Day == 1
    
    for i = 1:trainN
        
        if mod(i,Params.omissionN) == 0
            o.data.events.opto.opto_trial((i-1)*blockSize+1:(i-1)*blockSize+(Params.omission_blockSize*blockSize)) = 1;
            o.data.events.(movementType).opto_trial((i-1)*blockSize+1:(i-1)*blockSize+(Params.omission_blockSize*blockSize)) = 1;
        end
        
    end
    
end

% for i = 1:trainN
%     
%     r = randsample([thresh1 thresh2],1);
%     o.data.events.(movementType).ThresholdVector(:,i) = repmat(r,blockSize,1);
%     endZone_R = r + Params.zone_Size;
%     o.data.events.(movementType).endZone_ThresholdVector(:,i) = repmat(endZone_R,blockSize,1);
%     
%     
% end

if Params.Omission_Day == 1
    
        o.data.events.(movementType).omission_trial_types = zeros(trialN,1);
        for i = 1:trainN

            if mod(i,Params.omissionN) == 0
               o.data.events.(movementType).omission_trial_types((i-1)*blockSize+1:(i-1)*blockSize+(Params.omission_blockSize*blockSize)) = 1;
        %     else o.data.events.(movementType).omission_trial_types(i*blockSize+1:i*blockSize+blockSize) = 0;
            end

        end
elseif Params.Omission_Day == 2
             o.data.events.(movementType).omission_trial_types = zeros(trialN,1);
             o.data.events.(movementType).omission_trial_types(1:end) = 1;
else 
            o.data.events.(movementType).omission_trial_types = zeros(trialN,1);
end

o.data.events.(movementType).ThresholdVector = reshape(o.data.events.(movementType).ThresholdVector,[trialN,1]);
o.data.events.(movementType).endZone_ThresholdVector = reshape(o.data.events.(movementType).endZone_ThresholdVector,[trialN,1]);


%% initialize continuous data
o.data.continuous.cnt =0;
continuousNames = {'encoder' 'lick'};
nPrealloc = 10^8;
for i = 1:numel(continuousNames)
    o.data.continuous.(continuousNames{i}).time = nan(nPrealloc,1);
    o.data.continuous.(continuousNames{i}).value = nan(nPrealloc,1);
    o.data.continuous.(continuousNames{i}).cnt = 0;
end

% get params
soundseq_thresholds = cellfun(@(x) str2double(x),strsplit(Params.soundseq_thresholds,'/')); % Get soundseq thresholds from params GUI, and convert these strings to numbers. @(x) assigns function handle
% soundseq_kHz = cellfun(@(x) str2double(x),strsplit(Params.soundseq_kHz,'/')); % Get soundseq HZs from params GUI, and convert to numbers

% initialise flags
flag_isHome =1;
flag_prevIsHome =0;
flag_wentHome = 1;
flag_homeEnough = 1;
flag_isTarget = 0;
flag_previous_target = 0;
flag_target_enough = 0;
flag_reward =0;
flag_trial_type = 1;
flag_LEDon = 0;
flag_laserOn = 0;
flag_opto_trial = 0;
flag_laserWasTurnedOff = 0;
flag_align = 0;
flag_LEDIN = 0;
flag_solenoid = 0;
flag_rewardLED = 0;
flag_LEDOUT = 0;
flag_alignToneIN = 0;
flag_alignToneOUT = 0;
flag_alignHomeIN = 0;
flag_alignHomeOUT = 0;
flag_alignNegativePE = 0;
flag_wentBackwards = 0;

opto.cnt = 0;
mov.cnt = 0;
target.cnt = 0;
targetOUT.cnt = 0;
toneIN.cnt = 0;
toneOUT.cnt = 0;
alignPulse.cnt = 0;
tuningTones.cnt = 0;
alignNegativePE.cnt = 0;

th = 0; %Initialize threshold value
thEnd = 0; %Initialize thresholdEnd value

opto_trial_type_is_home_in = 0;
flag_PreviousIsTarget = 0;
flag_targetHomeFirst = 0;
flag_MissedZone = 0;
flag_toneOUT = 0;

% sounds to be played after behavior is done for tuning curves, in kHz
tuningCurveArduinoCommands = [21 1 22 2 23 24 25]; % Corresponds to [2kHz 16kHz 24kHz 8kHz 12kHz 4kHz 20kHz]; 

% initialize ConditionForValve
ConditionForValve = 0;       

% initialise force values
iFCntMax = Params.encoder_mov_window;
ENCODER =zeros(iFCntMax,1);

% initialise tics
TIC_toneRate = tic;
TIC_home = tic();
TIC_UpdateGUI = tic;
TIC_TargetIn = tic;
TIC_UpdateQuartile = tic;
TIC_DrawNow = tic;
TIC_rewardLED = tic;
TIC_solenoid = tic();
TIC_LED = tic;
TIC_laser = tic();
TIC_opto_delay = tic();
TIC_target = tic();
TIC_align = tic();
TIC_LEDOUT = tic();
TIC_toneOUT = tic();
TIC_LEDIN = tic();
TIC_alignToneIN = tic();
TIC_alignToneOUT = tic();
TIC_alignHomeIN = tic();
TIC_alignHomeOUT = tic();
TIC_alignNegativePE = tic();

timestamp_temp = -1;
o.addmsg('Start behavior loop');
disp('Start protocol loop')
trialEncoder = nan(10^5,1);
trialEncCnt = 0;

INPUTS = [0 0 0 0];
INPUTS(end) = 100000;
lastsize = 0;
while INPUTS(end) > Params.push_threshold_1
    fprintf(repmat('\b',1,lastsize));
    lastsize = fprintf('Waiting for mouse to be home...');
    pause(0.005)
    arduinoStr = fgets(arduinoRead1);
    EncAndVolt = strsplit(arduinoStr,'/');
    enc = str2double(EncAndVolt{1});
    INPUTS(end) = enc;

end


while o.el.Run.Value==1     
    %% ==================================
    %% Read out values
    %tic
    if Option_DispTICTOC==1
        ticALL=tic;
        ticReadOutVal =tic;
    end
    paramcell= o.params.t.Data;
    o.data.timestamp = GetSecs();
   
%     ENCODER = str2double(fgets(arduinoRead1));
%     VOLTAGE = str2double(fgets(arduinoRead2));

    arduinoStr = fgets(arduinoRead1);
    EncAndVolt = strsplit(arduinoStr,'/');
    ENCODER = str2double(EncAndVolt{1});
    VOLTAGE = str2double(EncAndVolt{2}(1:end-1)); 
   
    % log trial encoder data
    trialEncCnt = trialEncCnt+1;
    trialEncoder(trialEncCnt)= ENCODER;
    
    if Option_DispTICTOC==1
        tocReadOutVal =toc(ticReadOutVal);
        disp(['--tocReadOutVal: ' num2str(tocReadOutVal*1000)]);
    end
    
   
    %% ==================================
    %% Log input events (0.0517 ms)
  
    if Option_DispTICTOC==1
        ticLOG =tic;
    end
    
    %% Log analog data in continuous
    
       
    o.data.continuous.cnt = o.data.continuous.cnt+1;
    o.data.continuous.encoder.time(o.data.continuous.cnt,1) = o.data.timestamp;%figure;plot(o.data.continuous.encoder(:,2))
    o.data.continuous.encoder.value(o.data.continuous.cnt) = ENCODER;
    o.data.continuous.encoder.cnt = o.data.continuous.cnt;
        
    o.data.continuous.lick.time(o.data.continuous.cnt,1) = o.data.timestamp;%figure;plot(o.data.continuous.encoder(:,2))
    o.data.continuous.lick.value(o.data.continuous.cnt) = VOLTAGE;
    o.data.continuous.lick.cnt = o.data.continuous.cnt;
   
    
    if Option_DispTICTOC==1
        tocLOG=toc(ticLOG);
        disp(['------tocLOG: ' num2str(tocLOG*1000)]);
    end
    
    %% short variable names
    mov = o.data.events.(movementType);
    valve = o.data.events.valve;
    opto =  o.data.events.opto;
    target = o.data.events.target;
    targetOUT = o.data.events.targetOUT;
    toneIN = o.data.events.toneIN;
    toneOUT = o.data.events.toneOUT;
    alignPulse = o.data.events.alignPulse;

    
    %% ==================================
    %% WHAT IS THE CURRENT STATE (update flags)
    
    if Option_DispTICTOC==1
        ticIF = tic;
    end
    
    
    %% Check TIC TOCs for sending pulse times to Arduino
    
    if toc(TIC_toneOUT) > Params.toneOUT_delay && flag_toneOUT == 1
%               PsychPortAudio('Start', sounds.devHandlePlay(2), 1, 0);
              fprintf(arduinoWrite,37);
              TIC_alignToneOUT = tic();
              flag_alignToneOUT = 1;
              fprintf(arduinoWrite,2);
              toneOUT.cnt = toneOUT.cnt+1;
              toneOUT.time(toneOUT.cnt) = GetSecs;
              flag_toneOUT = 0;
              fprintf(arduinoWrite,15);
              TIC_LEDOUT = tic();
              flag_LEDOUT = 1;
    end
    
    if toc(TIC_alignToneIN) > Params.sound_standard_ms/1000 && flag_alignToneIN == 1
        fprintf(arduinoWrite,4);
        flag_alignToneIN = 0;
    end
    
    if toc(TIC_alignToneOUT) > Params.sound_standard_ms/1000 && flag_alignToneOUT == 1
        fprintf(arduinoWrite,38);
        flag_alignToneOUT = 0;
    end
    
    if toc(TIC_alignHomeOUT) > Params.sound_standard_ms/1000 && flag_alignHomeOUT == 1
        fprintf(arduinoWrite,29);
        flag_alignHomeOUT = 0;
    end
    
    if toc(TIC_solenoid) > Params.reward_ms/1000 && flag_solenoid == 1
              fprintf(arduinoWrite,14);
              flag_solenoid = 0;
    end
    
    if toc(TIC_rewardLED) > Params.LED_Duration_ms/1000 && flag_rewardLED == 1
              fprintf(arduinoWrite,6);
              flag_rewardLED = 0;
    end
    
    if toc(TIC_LEDOUT) > Params.LED_Duration_ms/1000 && flag_LEDOUT == 1
              fprintf(arduinoWrite,16);
              flag_LEDOUT = 0;
    end
    
    if toc(TIC_LEDIN) > Params.LED_Duration_ms/1000 && flag_LEDIN == 1
              fprintf(arduinoWrite,8);
              flag_LEDIN = 0;
    end
    
    if toc(TIC_alignHomeIN) > Params.sound_standard_ms/1000 && flag_alignHomeIN == 1
              fprintf(arduinoWrite,20);
              flag_alignHomeIN = 0;
    end
    
    if toc(TIC_alignNegativePE) > Params.sound_standard_ms/1000 && flag_alignNegativePE == 1
              fprintf(arduinoWrite,27);
              flag_alignNegativePE = 0;
    end
    
    if toc(TIC_laser) > Params.opto_duration_ms/1000 && flag_laserOn == 1
              fprintf(arduinoWrite,12);
              flag_laserOn = 0;
              opto.time_end(opto.cnt) = GetSecs;
              mov.opto_time_end(mov.cnt)=  GetSecs;
    end
    
    
    % Determine HOME IN OUT situation
    flag_isHome = abs(ENCODER) > Params.pull_threshold_1 && abs(ENCODER) < Params.push_threshold_1;
    HOME_IN = flag_prevIsHome==0 && flag_isHome;
    
    %% ::::::::::::::::::::::::::: if HOME IN, start timing last home position ::::::::::::::::::::::::::::::::::::::
    if HOME_IN% home in
        disp('HOME IN')
        TIC_home = tic();
        flag_wentHome = 1;
        flag_homeEnough = 0;
        flag_prevIsHome = 1;
        flag_isHome = 0;
        trialEncCnt = 0;
        flag_MissedZone = 0;
        flag_PreviousIsTarget = 0;
        fprintf(arduinoWrite,19);
        TIC_alignHomeIN = tic();
        flag_alignHomeIN = 1;
        flag_wentBackwards = 0;

 
        if flag_laserOn == 1
            flag_laserOn = 0;
            fprintf(arduinoWrite,12)
            opto.time_end(opto.cnt) = GetSecs;
            mov.opto_time_end(mov.cnt)=  GetSecs;
                
        end    
        
        %% log end of joystick event
        if mov.cnt > 0
        mov.time_end(mov.cnt) = o.data.timestamp;
        end  
 
        %% Give reward if rewarded trial
        %% * open valves   
        
        if  ConditionForValve == 1
            ConditionForValve = 0 ;
            flag_reward = 0;
            
            
            % log reward
            mov.rewarded(mov.cnt) = 1;
            mov.time_reward_s(mov.cnt)= GetSecs;
            valve.cnt = valve.cnt+1;
            valve.time(valve.cnt)=mov.time_reward_s(mov.cnt);
            fprintf(arduinoWrite,13);
            fprintf(arduinoWrite,5);  
            TIC_solenoid = tic();
            TIC_rewardLED = tic();
            flag_solenoid = 1;
            flag_rewardLED = 1;
            
            disp('valve')
            
            disp(['Rewarded :' num2str(valve.cnt)]);
            
        end


           
        %% Increment counter
        mov.cnt = mov.cnt+1;
     
    %% ================================
    %% == Choose next trial type

              %if mov.cnt > 0
              th = mov.ThresholdVector(mov.cnt);
              thEnd = mov.endZone_ThresholdVector(mov.cnt);
          
 
            disp ====================================
            MSG = [['Next trial' ':' num2str(mov.cnt) '    '] ['Opto=' num2str(mov.opto_trial(mov.cnt)) '    '] ['Target Zone=' num2str(mov.ThresholdVector(mov.cnt)) '-->' num2str(mov.endZone_ThresholdVector(mov.cnt)) '    '] ['Omission=' num2str(mov.omission_trial_types(mov.cnt)) ]];
            disp(MSG)
            
          

    end% end HOME IN
  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
   
    
    %% ::::::::::::::::::::::::::::::::: HOME TIME ::::::::::::::::::::::::::::::::::::::::::::::
    
    flag_homeEnough = toc(TIC_home)>Params.home_duration_ms/1000;
    if flag_homeEnough
        %% - slow loop: update GUI
        
        % Update values in the GUI if mouse is not performing when TIC_DrawNow counter is
        % above 2 seconds
        if toc(TIC_DrawNow)>2  && ENCODER<5 %&& flag_homeEnough==0
            drawnow;
            TIC_DrawNow = tic;
            [Params,optParams]=o.call_GetParams();
            
        end
        
        % If GUI has not updated since more than 30s, update it no matter what
        % position the encoder is in. Should not happen if code is running
        % correctly. Might happen if encoder has a baseline shift error
        if toc(TIC_DrawNow)>30
            drawnow;
            TIC_DrawNow = tic;
            [Params,optParams]=o.call_GetParams();
            
        end
    end
    
    
    %% ::::::::::::::::::::::::::: if HOME OUT, log new movement ::::::::::::::::::::::::::::::::::::::
    flag_homeout = ENCODER > Params.push_threshold_1;
    HOME_OUT = flag_prevIsHome==1 && flag_isHome==0 && flag_homeout;
    if  HOME_OUT
        flag_prevIsHome = 0;
        flag_isHome = 1;
        mov.time(mov.cnt) = GetSecs;
        flag_homeEnough = toc(TIC_home)>Params.home_duration_ms/1000;
        mov.ITI_respect(mov.cnt) = flag_homeEnough;
        fprintf(arduinoWrite,28);
        TIC_alignHomeOUT = tic();
        flag_alignHomeOUT = 1;
        
        %% *** OPTO ON + HOME OUT optogenetic trial - if optogenetic trial, send out pulse

                if mov.opto_trial(mov.cnt) == 1
                    % trigger laser
                    fprintf(arduinoWrite,11);
                    flag_laserOn = 1;
                    TIC_laser = tic();

                    % log opto event start
                    opto.cnt = opto.cnt+1;
                    opto.time(opto.cnt)= GetSecs;
                    mov.opto_time(mov.cnt)=  GetSecs;
        %         end
             end
    end

%% ==========================TARGET======================================
    %   th = mov.target_thresholds{mov.cnt};
    if Params.Training_Type == 1
        
        if abs(ENCODER) >= Params.Dead_Zone
            
            TARGET_LESS = flag_PreviousIsTarget==0 && flag_reward == 0 && flag_MissedZone == 0 && flag_homeout;
            
            if TARGET_LESS && o.data.continuous.encoder.value(o.data.continuous.cnt) < o.data.continuous.encoder.value(o.data.continuous.cnt-1) && flag_wentBackwards == 0
                
                fprintf(arduinoWrite,1);
                toneIN.cnt = toneIN.cnt+1;
                toneIN.time(toneIN.cnt) = GetSecs;
%                 PsychPortAudio('Start', sounds.devHandlePlay(1), 1, 0);
%                 toneIN.cnt = toneIN.cnt+1;
%                 toneIN.time(toneIN.cnt) = GetSecs;
                %         fprintf(arduinoWrite,3);
                %         TIC_align = tic();
                %         flag_align = 1;
                alignPulse.cnt = alignPulse.cnt+1;
                alignPulse.time(alignPulse.cnt) = GetSecs;
                target.cnt = target.cnt+1;
                target.time(target.cnt) = GetSecs;
                fprintf(arduinoWrite,7);
                TIC_LEDIN = tic();
                flag_LEDIN = 1;
                
                flag_reward = 1;
                
                flag_PreviousIsTarget = 1;
                
            end
        end
        
    else
        
        flag_isTarget  = abs(ENCODER) >= th(1);
        TARGET_IN = flag_isTarget==1 && flag_PreviousIsTarget==0 && flag_reward == 0 && flag_MissedZone == 0;
        if  TARGET_IN
            
            if mov.omission_trial_types(mov.cnt) == 0
                fprintf(arduinoWrite,3);
                TIC_alignToneIN = tic();
                flag_alignToneIN = 1;
                fprintf(arduinoWrite,1);
                toneIN.cnt = toneIN.cnt+1;
                toneIN.time(toneIN.cnt) = GetSecs;
%                 PsychPortAudio('Start', sounds.devHandlePlay(1), 1, 0);
%                 toneIN.cnt = toneIN.cnt+1;
%                 toneIN.time(toneIN.cnt) = GetSecs;
                %         fprintf(arduinoWrite,3);
                %         TIC_align = tic();
                %         flag_align = 1;
                alignPulse.cnt = alignPulse.cnt+1;
                alignPulse.time(alignPulse.cnt) = GetSecs;
                target.cnt = target.cnt+1;
                target.time(target.cnt) = GetSecs;
                fprintf(arduinoWrite,7);
                TIC_LEDIN = tic();
                flag_LEDIN = 1;
                
                flag_reward = 1;
                
                flag_PreviousIsTarget = 1;
                
                
                
            elseif mov.omission_trial_types(mov.cnt) == 1
                toneIN.cnt = toneIN.cnt+1;
                toneIN.time(toneIN.cnt) = GetSecs;
                fprintf(arduinoWrite,3);
                TIC_align = tic();
                flag_align = 1;
                alignPulse.cnt = alignPulse.cnt+1;
                alignPulse.time(alignPulse.cnt) = GetSecs;
                target.cnt = target.cnt+1;
                target.time(target.cnt) = GetSecs;
                fprintf(arduinoWrite,7);
                TIC_LEDIN = tic();
                flag_LEDIN = 1;
                
                flag_reward = 1;
                
                %         %turn the LED on and begin tic
                %         DIGITAL_OUTs(o.hardware.i4.LED) = 1;
                %         outputSingleScan(o.NI,DIGITAL_OUTs);
                flag_PreviousIsTarget = 1;
                
            end
            
            
        end
        
        
        if abs(ENCODER) > thEnd(1) && mov.omission_trial_types(mov.cnt) == 0 && flag_MissedZone == 0
            %         PsychPortAudio('Start', sounds.devHandlePlay(2), 1, 0);
            %         fprintf(arduinoWrite,2);
            %         toneOUT.cnt = toneOUT.cnt+1;
            %         toneOUT.time(toneOUT.cnt) = GetSecs;
            %         fprintf(arduinoWrite,15);
            %         TIC_LEDOUT = tic();
            %         flag_LEDOUT = 1;
            TIC_toneOUT = tic();
            flag_toneOUT = 1;
            targetOUT.cnt = targetOUT.cnt+1;
            targetOUT.time(targetOUT.cnt) = GetSecs;
            flag_reward = 0;
            flag_PreviousIsTarget = 0;
            flag_MissedZone = 1;
            
            
        elseif abs(ENCODER) > thEnd(1) && mov.omission_trial_types(mov.cnt) == 1 && flag_MissedZone == 0
            toneOUT.cnt = toneOUT.cnt+1;
            toneOUT.time(toneOUT.cnt) = GetSecs;
            targetOUT.cnt = targetOUT.cnt+1;
            targetOUT.time(targetOUT.cnt) = GetSecs;
            fprintf(arduinoWrite,17);
            TIC_alignToneOUT = tic();
            flag_alignToneOUT = 1;
            flag_reward = 0;
            flag_PreviousIsTarget = 0;
            flag_MissedZone = 1;
            fprintf(arduinoWrite,15);
            TIC_LEDOUT = tic();
            flag_LEDOUT = 1;
            
        end
        
        
        TARGET_LESS = abs(ENCODER) < thEnd(1) && flag_PreviousIsTarget==0 && flag_reward == 0 && flag_MissedZone == 0 && flag_homeout;
        
        if TARGET_LESS && o.data.continuous.encoder.value(o.data.continuous.cnt) < o.data.continuous.encoder.value(o.data.continuous.cnt-1) && flag_wentBackwards == 0
            
            fprintf(arduinoWrite,26);
            TIC_alignNegativePE = tic();
            flag_alignNegativePE = 1;
            flag_wentBackwards = 1;
            o.data.events.alignNegativePE.cnt = o.data.events.alignNegativePE.cnt+1;
            o.data.events.alignNegativePE.time(o.data.events.alignNegativePE.cnt) = GetSecs;
            
        end
        
       
    end
    
    %% * decide opening valve
    if flag_reward==1 
        if Params.reward_at_home ==0
            ConditionForValve = flag_wentHome && flag_homeEnough==1;
        elseif Params.reward_at_home ==1
            ConditionForValve = flag_wentHome && flag_reward ==1;
        end
    else
        ConditionForValve =0;
    end
    

    
    %% - If RealTimeTracking button pushed, display current encoder value
    if o.el.RealTimeTracking.Value==1
        MSGNEW = [[ENCODER] [VOLTAGE]];
        disp(MSGNEW)
        %disp(ENCODER)
    end
    
    %% update data with short variable names
    o.data.events.(movementType) = mov;
    o.data.events.valve =valve;
    o.data.events.opto = opto; 
    o.data.events.target = target;
    o.data.events.targetOUT = targetOUT;
    o.data.events.toneIN = toneIN;
    o.data.events.toneOUT = toneOUT;
    o.data.events.alignPulse = alignPulse;

 %toc
end% while

disp('Stopped protocol')

fprintf(arduinoWrite,14); % Turn Solenoid LOW in case it was HIGH just as code was stopped
fprintf(arduinoWrite,16);
fprintf(arduinoWrite,8);
fprintf(arduinoWrite,6);

if Params.Tuning_Tones == 1
pause(60*10)

for i = 1:20
    
    for s = 1:length(tuningCurveArduinoCommands)
        
        fprintf(arduinoWrite,3);
        fprintf(arduinoWrite,tuningCurveArduinoCommands(s));
        tuningTones.cnt = tuningTones.cnt + 1;
        o.data.events.tuningTones.time(tuningTones.cnt) = GetSecs;
        o.data.events.tuningTones.value(tuningTones.cnt) = s;
        pause(0.050)
        fprintf(arduinoWrite,4);
        pause(1)
        
    end
    
    
end

end

fclose(arduinoWrite); % Close Arduino Serial Com Channel
fclose(arduinoRead1); % Close Arduino Serial Com Channel
%fclose(arduinoRead2); % Close Arduino Serial Com Channel

%% StopCam script
StopNCam;
if o.el.Autosave.Value ==1
    o.call_SaveData();
end
