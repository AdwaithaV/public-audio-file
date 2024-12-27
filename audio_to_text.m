
apiKey = 'your_API_KEY';
audioFileURL = 'https://drive.google.com/file/d/1UExMoQgevOefPLkmuJdKYiiwheNZZw7j/view?usp=sharing'; % Public URL of the audio file


requestData = jsonencode(struct('media_url', audioFileURL));


options = weboptions('HeaderFields', {'Authorization', ['Bearer ' apiKey]}, ...
                     'RequestMethod', 'POST', ...
                     'Timeout', 60, ...
                     'MediaType', 'application/json');
 

disp('Uploading the audio file...');
uploadURL = 'https://api.rev.ai/speechtotext/v1/jobs';
try
    response = webwrite(uploadURL, requestData, options);
    jobId = response.id;
    disp(['Audio file uploaded successfully.']);
    disp(['Job ID: ', jobId]); 
catch ME
    disp(['Error during file upload: ', ME.message]);
    return;
end


disp('Polling for transcription result...');
checkURL = ['https://api.rev.ai/speechtotext/v1/jobs/' jobId];
status = '';
while ~strcmp(status, 'transcribed') && ~strcmp(status, 'failed')
    pause(5); 
    try
        response = webread(checkURL, weboptions('HeaderFields', {'Authorization', ['Bearer ' apiKey]}));
        status = response.status;
        disp(['Current Status: ', status]);
    catch ME
        disp(['Error while checking status: ', ME.message]);
        return;
    end
end


if strcmp(status, 'transcribed')
    disp('Transcription completed successfully!');
    try
        
        resultURL = ['https://api.rev.ai/speechtotext/v1/jobs/' jobId '/transcript'];
        
      
        transcriptResponse = webread(resultURL, ...
            weboptions('HeaderFields', {'Authorization', ['Bearer ' apiKey], ...
                                        'Accept', 'application/json'}));  % Correct format

        jsonFileName = [jobId '_transcription.json'];
        fid = fopen(jsonFileName, 'w');
        if fid == -1
            disp(['Error: Unable to save JSON file as ', jsonFileName]);
        else
            fprintf(fid, '%s', jsonencode(transcriptResponse, 'PrettyPrint', true));
            fclose(fid);
            disp(['Transcription saved to JSON file: ', jsonFileName]);
        end

      
        txtFileName = [jobId '_transcription.txt'];
        txtFileID = fopen(txtFileName, 'w');
        if txtFileID == -1
            disp(['Error: Unable to save .txt file as ', txtFileName]);
        else
           
            transcriptText = extractTranscript(transcriptResponse); 
            if ~isempty(transcriptText)
                fprintf(txtFileID, '%s', transcriptText);
                fclose(txtFileID);
                disp(['Transcription saved to .txt file: ', txtFileName]);
            else
                disp('No transcribed text found.');
            end
        end

        if exist(txtFileName, 'file') 
            fid = fopen(txtFileName, 'r');
            if fid == -1
                disp('Error opening .txt file for reading.');
            else
                transcribedText = fread(fid, '*char')';
                disp('Transcribed Text:');
                disp(transcribedText);
                fclose(fid);
            end
        end

    catch ME
        disp(['Error fetching transcription text: ', ME.message]);
    end
else
    disp('Error: Transcription failed.');
end

% Helper function to extract transcription text from response
function transcriptText = extractTranscript(transcriptResponse)
    transcriptText = ""; % Initialize an empty string
    try
        if isfield(transcriptResponse, 'monologues') && ~isempty(transcriptResponse.monologues)
            for i = 1:length(transcriptResponse.monologues)
                monologue = transcriptResponse.monologues(i);
                if isfield(monologue, 'elements') && ~isempty(monologue.elements)
                    for j = 1:length(monologue.elements)
                        element = monologue.elements(j);
                        if isfield(element, 'text') && ischar(element.text)
                            transcriptText = strcat(transcriptText, " ", element.text);
                        end
                    end
                end
            end
        end
    catch
        disp('Error: Unexpected structure in transcription response.');
    end
    transcriptText = strtrim(transcriptText); % Remove leading/trailing spaces
end



