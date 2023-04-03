% PowerShell - Execute a command in PowerShell asynchronously and receive a
% response when ready.
% 
% Example:
%   shell = PowerShell('echo hello!', @disp);
%   while shell.step()
%   end
%   % When the command finishes executing, this example will display "hello!".

% 2019-05-25. Leonardo Molina.
% 2022-11-03. Last modified.
classdef PowerShell < handle
    properties (Dependent)
        busy
        callback
        response
    end
    
    properties (Access = private)
        retrieved = false
        processBuilder
        inputStream
        process
        isProcess = false
        mCallback = @(~) true
        mResponse = ''
    end
    
    methods
        % PowerShell() ==> do nothing.
        % PowerShell(command) ==> call and block.
        % PowerShell(command, callback) ==> call and release.
        function obj = PowerShell(command, callback)
            obj.processBuilder = java.lang.ProcessBuilder({''});
            obj.processBuilder.directory(java.io.File(pwd));
            obj.processBuilder.redirectErrorStream(true);
            
            switch nargin
                case 1
                    obj.run(command, true);
                case 2
                    obj.callback = callback;
                    obj.run(command, false);
            end
        end
        
        function delete(obj)
            if obj.isProcess
                obj.process.destroy();
            end
        end
        
        function run(obj, command, block)
            if nargin < 3
                block = false;
            end

            if obj.isProcess
                obj.process.destroy();
            end
            obj.processBuilder.command({'powershell.exe', command});
            obj.process = obj.processBuilder.start();
            obj.inputStream = obj.process.getInputStream();
            obj.isProcess = true;
            obj.retrieved = false;

            if block
                while obj.step()
                end
            end
        end
        
        function busy = get.busy(obj)
            busy = obj.isProcess && obj.process.isAlive == 1;
        end
        
        function callback = get.callback(obj)
            callback = obj.mCallback;
        end
        
        function set.callback(obj, callback)
            if isa(callback, 'function_handle')
                obj.mCallback = callback;
            else
                error(sprintf('%s:SetCallbackError', mfilename('class')), 'Provided argument is not a valid function handle.');
            end
        end

        function response = get.response(obj)
            response = obj.mResponse;
        end
        
        function busy = step(obj)
            busy = obj.busy;
            if obj.isProcess && ~obj.retrieved && obj.process.isAlive == 0
                scanner = java.util.Scanner(obj.inputStream).useDelimiter('\A');
                if scanner.hasNext()
                    obj.mResponse = strtrim(char(scanner.next()));
                else
                    obj.mResponse = '';
                end
                obj.retrieved = true;
                obj.callback(obj.mResponse);
            end
        end
    end

    methods (Static)
        function response = Run(command)
            obj = PowerShell(command);
            response = obj.response;
            obj.delete();
        end
    end
end