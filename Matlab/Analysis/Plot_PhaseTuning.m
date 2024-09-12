function phaseTuning=Plot_PhaseTuning(whiskerPhase,ephysData,...
    dataMask,labels,splitEpochs,saveFig)
% whiskingPhase in radians
% spikeRate in Hz

colormapSeed=lines; cmap=[colormapSeed(1:7,:);(colormapSeed+flipud(copper))/2;autumn];

if isfield(ephysData.recInfo,'sessionName'); recName=ephysData.recInfo.sessionName;
else; recName='PhaseTuning_polarPlot'; end

%% Data masking: look at each whisking epoch
wEpochs.behav=bwconncomp(dataMask.behav);
% mask epochs with short whisking bouts
durationThd=cellfun(@(x) length(x),wEpochs.behav.PixelIdxList)>=3000;
dataMask.behav(vertcat(wEpochs.behav.PixelIdxList{~durationThd}))=false;
wEpochs.behav.PixelIdxList=wEpochs.behav.PixelIdxList(durationThd);
if splitEpochs
    wEpochs.behav.NumObjects=sum(durationThd);
else
    wEpochs.behav.PixelIdxList={vertcat(wEpochs.behav.PixelIdxList{:})};
    wEpochs.behav.NumObjects=1;
end
% do the same for ephys data
wEpochs.ephys=bwconncomp(dataMask.ephys);
dataMask.ephys(vertcat(wEpochs.ephys.PixelIdxList{~durationThd}))=false;
wEpochs.ephys.PixelIdxList=wEpochs.ephys.PixelIdxList(durationThd);
if splitEpochs
    wEpochs.ephys.NumObjects=sum(durationThd);
else
    wEpochs.ephys.PixelIdxList={vertcat(wEpochs.ephys.PixelIdxList{:})};
    wEpochs.ephys.NumObjects=1;
end

spikeRasters = ephysData.rasters(ephysData.selectedUnits,:);
spikeRate=ephysData.spikeRate(ephysData.selectedUnits,:);

%% normalized whisker angle
if false
    cycleAngle=cell(numel(ptWhisks.PixelIdxList),1);
    if numel(ptWhisks.PixelIdxList)>1000
        %take sample
        whiskList=1:round(numel(ptWhisks.PixelIdxList)/1000):numel(ptWhisks.PixelIdxList);
    else
        whiskList=1:numel(ptWhisks.PixelIdxList);
    end
    for whiskCycle=1:numel(whiskList)
        peakWhiskIdx=ptWhisks.PixelIdxList{whiskList(whiskCycle)}(1);
        %     if whiskCycle>1
        wCycleSIdx=peakWhiskIdx-find(whiskerPhase(peakWhiskIdx-1:-1:1)>0,1)+1;
        %     else
        %         wCycleSIdx=peakWhiskIdx-find(whiskerPhase(peakWhiskIdx-1:-1:1)<0,1,'last'); %should be one
        %     end
        if ~isempty(wCycleSIdx)
            wCycleEIdx=ptWhisks.PixelIdxList{whiskList(whiskCycle)}(end);
            [cycleAngle{whiskCycle},phaseValues]=...
                resample(whiskerAngle(wCycleSIdx:wCycleEIdx),...
                whiskerPhase(wCycleSIdx:wCycleEIdx));
            cycleAngle{whiskCycle} = interp1(phaseValues,cycleAngle{whiskCycle},linspace(-pi,pi,100));
            %normalize
            cycleAngle{whiskCycle} =rescale(cycleAngle{whiskCycle});
        else
            continue
        end
    end
    cycleAngle=vertcat(cycleAngle{:});
    %             plot(linspace(-pi,pi,100),nanmean(cycleAngle),'k')
    %             set(gca,'ytick',[0 0.5 1],'xtick',[-pi 0 pi],'xticklabel',{'0','\pi','2\pi'})
    %             set(gca,'tickdir','out')
    %             % xlabel('Phase \phi (radians)')
    %             ylabel('Normalized whisker angle')
end

for unitNum=1:size(spikeRasters,1)
    
    if mean(spikeRate(unitNum,:)) < 0.5
        continue
    end
    
    numEpochs=wEpochs.behav.NumObjects;

    for wEpochNum=1:numEpochs

            figure('name',['Unit ' num2str(ephysData.selectedUnits(unitNum)) ' - ' recName ...
                ' - Tuning to ' labels ' phase'],'Color','white','position',...
                [214   108   747   754]);

        clearvars eWhiskerPhase sp2H sp3H sp4H
        eWhiskerPhase=whiskerPhase(wEpochs.behav.PixelIdxList{wEpochNum});
        
        %         ptWhisks=bwconncomp(eWhiskerPhase>0);
        %% probability density function of phase for spiking events
        numBins=32; % each bin = pi/16 radians
        edges = linspace(min(eWhiskerPhase), max(eWhiskerPhase), numBins*2+1);
        %         edges = linspace(-pi-pi/numBins,pi+pi/numBins, numBins+1);
        centers = mean([ edges(1:end-1); edges(2:end) ]);
        [ ~, ~, phaseBins ] = histcounts(eWhiskerPhase, edges);
        samplingRate=1000; %change in case this isn't at 1kHz SR
        phaseTuning=nan(size(spikeRate,1),numEpochs);
        
        try
            unitSpikeEvent=spikeRasters(unitNum,wEpochs.ephys.PixelIdxList{wEpochNum});
            attribPhaseBin = phaseBins(logical(unitSpikeEvent));
            %     number of spikes in each phase bin N(?k|spike)
            spikePhaseBinCount=histcounts(attribPhaseBin,[1 1+unique(phaseBins)]);%         [spikePhaseBinCount,uniqueSpikePhaseBins]=hist(phaseVals,unique(phaseVals));
            %     probability density function P(?k|spike)
            spikePhasePDF=spikePhaseBinCount/sum(spikePhaseBinCount);
            spikePhasePDF=sum(reshape([spikePhasePDF(2:end),spikePhasePDF(1)],2,numBins))/2;
            spikePhasePDF=[spikePhasePDF(end) spikePhasePDF];
            %         spikePhasePDF=movsum(spikePhasePDF,6);spikePhasePDF=spikePhasePDF(6:6:end);
            %     number of phase occurence for each phase bin N(?k)
            phaseBinCount=histcounts(phaseBins,[1 1+unique(phaseBins)]);
            %     probability density function P(?k)
            phasePDF=phaseBinCount/sum(phaseBinCount);
            phasePDF=sum(reshape([phasePDF(2:end),phasePDF(1)],2,numBins))/2;
            phasePDF=[phasePDF(end) phasePDF];
            %         phasePDF=movsum(phasePDF,2);phasePDF=phasePDF(2:2:end);
            % mean spike rate for each phase bin ?[?k] = SR*N(?k|spike)/N(?k)
            meanPhaseSpikeRate=samplingRate*spikePhaseBinCount./phaseBinCount;
            %     fit sine wave
            %     modulation depth of the averaged whisking response
            
            %% plot
            
            %plot PDF
            sp2H=subplot(2,2,4); hold on ; %(4,numEpochs,numEpochs+wEpochNum)
            plot(linspace(-pi,pi, numBins+1),smooth(spikePhasePDF),'linewidth',1.2,'Color', [0 0 0]); %centers
            plot(linspace(-pi,pi, numBins+1),smooth(phasePDF),'linewidth',1.2,'Color', [0 0 0 0.5]); %centers
            set(gca,'ytick',0:0.05:1,...
                'xlim',[-pi pi],'xtick',[-pi 0 pi],'xticklabel',{'-\pi','0','\pi'},...
                'tickdir','out');
%             axis tight
            if wEpochs.behav.NumObjects==1
                %                 'ylim',[0 0.1]
                %               ylabel('PDF')
            end
            legend('P(\phi_k|spike)','P(\phi_k)','location','southeast')
            legend('boxoff')
            title({'Probability density function'; 'of phase for spiking events'})
            %plot spike rate
            %             subplot(numEpochs,5,(wEpochNum-1)*5+3); hold on
            %             %bar / histogram of mean spike rates
            %             bar(centers,meanPhaseSpikeRate)
            %             % sine fit
            %             yLim=get(gca,'ylim');
            %             set(gca,'ytick',0:50:max(yLim),'xtick',[-pi 0 pi],'xticklabel',{'0','\pi','2\pi'},'tickdir','out')
            % %             ylabel('Spike rate (Hz)')
            % %             xlabel('Phase \phi (radians) ')
            %             % end
            
            % for unitNum=1:size(spikeRate,1)
            clearvars unitSpikeRate
            eSpikeRate= spikeRate(unitNum,wEpochs.ephys.PixelIdxList{wEpochNum});
            [binMeanSpikeRate,binSESpikeRate]=deal(nan(numBins*2,1));

            sp3H=subplot(2,2,3);hold on; %(4,numEpochs,numEpochs*2+wEpochNum)
            clearvars binMeanSpikeRate binSESpikeRate

            % Bining firing rate and spikes
            for binNum = 1:length(edges)-1 % : -1 : 1
                ratesVect= eSpikeRate(phaseBins == binNum);
                numSample = numel(ratesVect);
                if numSample == 0
                    meanSpikeRate = 0;
                    steSpikeRate = 0;
                else
                    meanSpikeRate = nanmean(ratesVect);
                    steSpikeRate = MMath.StandardError(ratesVect);
                end
                binMeanSpikeRate(binNum) = meanSpikeRate;
                binSESpikeRate(binNum) = steSpikeRate;
            end
            
            %           rescale
            rsbinMeanSpikeRate=sum(reshape([binMeanSpikeRate(2:end),binMeanSpikeRate(1)],2,numBins))/2;
            rsbinMeanSpikeRate=[rsbinMeanSpikeRate(end) rsbinMeanSpikeRate];
            rsbinSESpikeRate=sum(reshape([binSESpikeRate(2:end),binSESpikeRate(1)],2,numBins))/2;
            rsbinSESpikeRate=[rsbinSESpikeRate(end) rsbinSESpikeRate];

            plot(linspace(-pi,pi, numBins+1), rsbinMeanSpikeRate,'Color','k', 'LineWidth',2) %centers %,'color',cmap(unitNum,:));%'k'
            patch([linspace(-pi,pi, numBins+1),linspace(pi,-pi, numBins+1)],...
                [rsbinMeanSpikeRate-rsbinSESpikeRate,fliplr(rsbinMeanSpikeRate+rsbinSESpikeRate)],...
                'k','EdgeColor','none','FaceAlpha',0.2); %cmap(cellNum,:)

    %             end
            %             xlabel({'Phase  (rad)'; '0 = Max Protraction'}, 'FontSize', 18);
            %             ylabel('Firing rate (Spk/s)', 'FontSize', 18);
            axis tight
            yl = ylim;
            ylim([0 yl(2)]);
            text(0,  yl(2)/10, '0 = Max protraction')
            set(gca,'xlim',[-pi pi],'xtick',[-pi 0 pi],'xticklabel',{'-\pi','0','\pi'},...
                'tickdir','out');
            box off
            if wEpochs.behav.NumObjects==1
                xlabel('Phase (radians)')
                ylabel('Spike rate (Hz)')
            end
            title({'Average spike rate'; ['across ' labels ' phase']})
            % set(gca,'xdir', 'reverse'); %, 'ydir', 'reverse')
            %% convert to thetas: make as many phase # as FR for that phase #
            thetas=cell(numel(centers),1);
            for binNum=1:numel(centers)
                thetas{binNum}=ones(round(binMeanSpikeRate(binNum)),1)*centers(binNum);
            end
            thetas=vertcat(thetas{:});
            if isempty(thetas)
                disp('not enough spikes')
                continue
            end
            % stats
            phaseStats=circ_stats(thetas);
            if  circ_rtest(thetas)<0.05 
                phaseTuning(unitNum,1)=rad2deg(phaseStats.mean);
            end
            if ~isnan(phaseTuning(unitNum,1))
                phEdgeColor=cmap(unitNum,:);phFaceColor=cmap(unitNum,:);
 
            else
                phEdgeColor='k';phFaceColor='k'; %EdgeAlpha=0.5;
            end
                       
            sp4H=subplot(2,2,[1 2]); 
            polarhistogram(thetas,edges,'Displaystyle','bar',...
                'Normalization','count','LineWidth',2,...
                'EdgeColor',phEdgeColor,'FaceColor',phFaceColor,...
                'EdgeAlpha',0);
            paH = gca;
            paH.ThetaZeroLocation='left';
            paH.ThetaTickLabel={'max Protraction','','','Retraction','','',...
                'max Retraction','','','Protraction','',''};
            paH.ThetaDir = 'counterclockwise';

            title(['Unit ' num2str(ephysData.selectedUnits(unitNum)) ' - ' strrep(recName,'_','') ...
                ' - Tuning to ' labels ' phase'],'interpreter','none');
            
        catch
            continue
        end
    end

end

if saveFig
    savefig(phaseTuningSummaryFig,[ephys.recName '_phaseTuningSummary.fig'])
    saveas(phaseTuningSummaryFig,[ephys.recName '_phaseTuningSummary.png'])
end
