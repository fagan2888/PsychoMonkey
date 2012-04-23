% PsychoMonkey
% Copyright (C) 2012 Simon Kornblith
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as
% published by the Free Software Foundation, either version 3 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Affero General Public License for more details.
% 
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

classdef PMServer < handle
% PMServer Server for observing paradigms over a network
    properties(Constant = true)
        % Maximum rate at which updates will be sent to the socket, in Hz
        MAX_UPDATE_RATE = 100;
    end
    
    properties(Access = private)
        server;
        lastEyePositionUpdateTime = -1;
        drawCommands = {};
    end
    
    methods
        function self = PMServer()
            global CONFIG PM;
            
            % Set Java classpath
            pathToPMServer = fileparts(which('PMServer.m'));
            javaClasspaths = {fullfile(pathToPMServer, 'bin', 'com', ...
                'simonster', 'PsychoMonkey'), ...
                fullfile(pathToPMServer, 'Java-WebSocket', 'dist', ...
                'WebSocket.jar')};
            javaclasspath(javaClasspaths, javaclasspath('-dynamic'));
            
            % Initialize server
            import com.simonster.PsychoMonkey;
            self.server = PsychoMonkey.PMServer(CONFIG);
            
            % Hook into OSD and event loop
            addListener(PM.osd, 'targetsChanged', @self.onTargetsChanged);
            addListener(PM.osd, 'statusChanged', @self.onStatusChanged);
            addListener(PM.screenManager, 'screenCommand', @self.onScreenCommand);
            PM.eventLoop{end+1} = @updateEyePosition;
        end
        
        function onTargetsChanged(self)
            global PM;
            self.server.updateTargets(savejson('', ...
                struct('targetRects', PM.osd.targetRects, ...
                'targetIsOval', PM.osd.targetIsOval)));
        end
        
        function onStatusChanged(self)
            global PM;
            self.server.updateStatus(savejson('', ...
                struct('state', PM.osd.state, ...
                'performance', PM.osd.performance, ...
                'keyInfo', PM.osd.keyInfo)));
        end
        
        function onScreenCommand(self, command)
            if strcmp(command{1}, 'Flip')
                self.server.updateDisplay(savejson('', self.drawCommands, ...
                    'NoRowBracket', 1));
                self.drawCommands = {};
            elseif(strcmp(command{1}, 'MakeTexture'))
                self.server.addTexture(command{2}, command{3});
            else
                self.drawCommands{end+1} = command;
            end
        end
        
        function updateEyePosition(self)
            t = GetSecs();
            if self.lastEyePositionUpdateTime-t > 1/self.MAX_UPDATE_RATE
                eyePosition = CONFIG.eyeTracker.getEyePosition();
                self.server.updateEyePosition(eyePosition(1), eyePosition(2));
            end
        end
    end
end
