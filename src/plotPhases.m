% Plot swing and stance.

% 2022-07-11. Leonardo Molina.
% 2022-11-28. Last modified.
function plotPhases(CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY, minStrideDuration, maxStrideDuration, minPhaseProminenceSD, acquisitionRate)
    nFrames = numel(CX);
    time = (0:nFrames - 1) / acquisitionRate;
    
    % Color map encoding swing and stance phases.
    cmap = [0.85, 0.85, 0.85;
            1.00, 1.00, 1.00];
    
    % Distance from center.
    angle = circular.mean(CA);
    FLM = project(angle, FLX - CX, FLY - CY);
    FRM = project(angle, FRX - CX, FRY - CY);
    BLM = project(angle, BLX - CX, BLY - CY);
    BRM = project(angle, BRX - CX, BRY - CY);
    
    fcn = @(x, y) getPhases(x, y, CA, minStrideDuration * acquisitionRate, maxStrideDuration * acquisitionRate, minPhaseProminenceSD);
    FLP = fcn(FLX - CX, FLY - CY);
    FRP = fcn(FRX - CX, FRY - CY);
    BLP = fcn(BLX - CX, BLY - CY);
    BRP = fcn(BRX - CX, BRY - CY);
    
    m = [FLM; FRM; BLM; BRM];
    ylims = [min(m), max(m)];
    
    plotOptions = {'-'};
    
    ax(1) = subplot(4, 1, 1);
    hold('all');
    h = patchPlot(FLP, acquisitionRate, ylims, cmap);
    h(1).DisplayName = 'Swing';
    h(2).DisplayName = 'Stance';
    [h.HandleVisibility] = deal('off');
    plot(time, FLM, plotOptions{:}, 'DisplayName', 'FL');
    legend(ax(1), 'show', 'Location', 'SouthEast');
    
    ax(2) = subplot(4, 1, 2);
    hold('all');
    h = patchPlot(FRP, acquisitionRate, ylims, cmap);
    h(1).DisplayName = 'Swing';
    h(2).DisplayName = 'Stance';
    [h.HandleVisibility] = deal('off');
    plot(time, FRM, plotOptions{:}, 'DisplayName', 'FR');
    legend(ax(2), 'show', 'Location', 'SouthEast');
    
    ax(3) = subplot(4, 1, 3);
    hold('all');
    h = patchPlot(BLP, acquisitionRate, ylims, cmap);
    h(1).DisplayName = 'Swing';
    h(2).DisplayName = 'Stance';
    [h.HandleVisibility] = deal('off');
    plot(time, BLM, plotOptions{:}, 'DisplayName', 'BL');
    legend(ax(3), 'show', 'Location', 'NorthEast');
    
    ax(4) = subplot(4, 1, 4);
    hold('all');
    h = patchPlot(BRP, acquisitionRate, ylims, cmap);
    h(1).DisplayName = 'Swing';
    h(2).DisplayName = 'Stance';
    [h.HandleVisibility] = deal('off');
    plot(time, BRM, plotOptions{:}, 'DisplayName', 'BR');
    legend(ax(4), 'show', 'Location', 'NorthEast');
    xlabel('Time (s)');
    ylabel('Amplitude (mm)');
    
    set(ax(1:3), 'xTick', []);
    axis(ax, 'tight');
end

% 2022-07-12. Leonardo Molina.
% 2022-07-14. Last modified.
function h = patchPlot(phases, frequency, ylims, cmap)
    if nargin < 3
        ylims = ylim();
    end
    [swingEpochs, stanceEpochs] = flagToEpochs(phases, true);
    swingEpochs = (swingEpochs - 1) / frequency;
    stanceEpochs = (stanceEpochs - 1) / frequency;
    [swingFaces, swingVertices] = patchEpochs(swingEpochs, ylims(1), ylims(2));
    h(1) = patch('Faces', swingFaces, 'Vertices', swingVertices, 'FaceColor', cmap(1, :), 'EdgeColor', 'none', 'FaceAlpha', 0.50);
    [stanceFaces, stanceVertices] = patchEpochs(stanceEpochs, ylims(1), ylims(2));
    h(2) = patch('Faces', stanceFaces, 'Vertices', stanceVertices, 'FaceColor', cmap(2, :), 'EdgeColor', 'none', 'FaceAlpha', 0.50);
end