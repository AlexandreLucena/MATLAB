% =============================================================
% Script para leitura contínua da porta serial
% -------------------------------------------------------------
% -- -- Por Alexandre S. Lucena
% -------------------------------------------------------------
% - O objetivo deste código é proporcionar a leitura contínua
% da porta serial, plotando resultados em formato preparado
% para sistemas de controle, separando entre referência, saída
% e ação de controle. Há um quinto dado que deve ser recebido
% preparado para ser a leitura da função millis() do Arduino,
% visando posterior análise de tempo de amostragem. Entretanto, 
% este dado não é plotado, apenas guardado.
% - Os dados lidos por este código são salvos em um arquivo de
% tabela .csv nomeado como "dados_coletados.csv" que deve ser
% importado ao workspace para a manipulação de dados.
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% -- Alguns detalhes 
% - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
% - Antes de iniciar, confira se a variável "porta" aponta
% para a porta serial correta.
% - Antes de iniciar, confira se o baud rate está correto.
% - Para estabelecer a conexão com o MATLAB é necessário 
% assegurar que a não há conexão anteriormente estabelecida 
% (se um Arduino estiver sendo utilizado será necessário
% fechar o serial plotter e o serial monitor).
% - Devem ser enviados cinco dados, separados por vírgula
% =============================================================

clc;
clear;
close all;

% Configuração Serial
porta = "COM3";  
baud_rate = 115200;
s = serialport(porta, baud_rate);
configureTerminator(s, "LF");
flush(s);
pause(2);

% Parâmetros de suavização
windowSize = 5; % Tamanho da janela para média móvel

% Pré-alocação de memória
bufferSize = 10000;
tempo = zeros(bufferSize, 1);
Entrada = zeros(bufferSize, 1);
Saida = zeros(bufferSize, 1);
Saida_filtrada = zeros(bufferSize, 1);
AC = zeros(bufferSize, 1);
Millis = zeros(bufferSize, 1);
count = 0;

% Configuração do arquivo de log
fileID = fopen('dados_coletados.csv', 'w');
fprintf(fileID, 'Tempo(s),Referência,Saida,Saida_filtrada,AC,Millis\n');

% Configuração dos gráficos
figure('DoubleBuffer', 'on');
h1 = subplot(2,1,1);
p1 = plot(NaN, NaN, '--', 'LineWidth', 1);
hold on;
p2 = plot(NaN, NaN, 'r-', 'LineWidth', 1);
p3 = plot(NaN, NaN, 'g-', 'LineWidth', 1.5);
legend("Referência", "Saída", "Saída Filtrada");
title("Sinais de Controle");
grid on;

h2 = subplot(2,1,2);
p4 = plot(NaN, NaN, 'm-', 'LineWidth', 1);
legend("Ação de Controle");
grid on;

tempo_inicio = tic;
lastUpdate = toc(tempo_inicio);
updateInterval = 0.01; % 50ms

try
    while true
        while s.NumBytesAvailable > 0
            linha = readline(s);
            valores = sscanf(linha, '%f,%f,%f,%f');
            
            if numel(valores) == 4
                count = count + 1;
                
                if count > bufferSize
                    tempo = [tempo; zeros(bufferSize, 1)];
                    Entrada = [Entrada; zeros(bufferSize, 1)];
                    Saida = [Saida; zeros(bufferSize, 1)];
                    Saida_filtrada = [Saida_filtrada; zeros(bufferSize, 1)];
                    AC = [AC; zeros(bufferSize, 1)];
                    Millis = [Millis; zeros(bufferSize, 1)];
                    bufferSize = bufferSize * 2;
                end
                
                tempo(count) = toc(tempo_inicio);
                Entrada(count) = valores(1);
                Saida(count) = valores(2);
                AC(count) = valores(3);
                Millis(count) = valores(4);
                
                % Suavização com mediana móvel - CORREÇÃO AQUI
                if count >= windowSize
                    % Calcula a mediana móvel para a janela atual
                    valorfiltrado = median(Saida(max(1,count-windowSize+1):count));
                    Saida_filtrada(count) = valorfiltrado;
                else
                    Saida_filtrada(count) = Saida(count);
                end
                
                fprintf(fileID, '%f,%f,%f,%f,%f,%f\n', ...
                    tempo(count), Entrada(count), Saida(count), Saida_filtrada(count), AC(count), Millis(count));
            end
        end
        
        currentTime = toc(tempo_inicio);
        if currentTime - lastUpdate >= updateInterval && count > 0
            range = max(1, count-1000):count;
            
            set(p1, 'XData', tempo(range), 'YData', Entrada(range));
            set(p2, 'XData', tempo(range), 'YData', Saida(range));
            set(p3, 'XData', tempo(range), 'YData', Saida_filtrada(range));
            xlim(h1, [max(0, tempo(count)-10), tempo(count)]);
            ylim(h1, [min([Entrada(range); Saida(range)])-10, max([Entrada(range); Saida(range)])+10]);
            
            set(p4, 'XData', tempo(range), 'YData', AC(range));
            xlim(h2, [max(0, tempo(count)-10), tempo(count)]);
            ylim(h2, [min(AC(range))-5, max(AC(range))+5]);
            
            % set(p5, 'XData', tempo(range), 'YData', Millis(range));
            % xlim(h3, [max(0, tempo(count)-10), tempo(count)]);
            
            drawnow limitrate;
            lastUpdate = currentTime;
        end
        
        pause(0.001);
    end
catch ME
    fclose(fileID);
    delete(s);
    rethrow(ME);
end

fclose(fileID);
delete(s);