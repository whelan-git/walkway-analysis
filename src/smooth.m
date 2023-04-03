% 2022-07-11. Leonardo Molina.
% 2022-07-11. Last modified.
function smoothed = smooth(data, sigma, n)
    kernelSize = ceil(n * sigma);
    % Odd kernel size.
    kernelSize = kernelSize - ~mod(kernelSize, 2);
    alpha = (kernelSize - 1) / sigma / 2;
    % Create kernel.
    kernel = gausswin(kernelSize, alpha);
    % Normalize kernel.
    kernel = kernel ./ sum(kernel);
    smoothed = conv(data, kernel, 'same');
end