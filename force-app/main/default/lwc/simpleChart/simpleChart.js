import { LightningElement, api } from 'lwc';

export default class SimpleChart extends LightningElement {
    @api chartType = 'bar';
    @api chartData;
    
    colors = ['#1589EE', '#4BCA81', '#FFB75D', '#E74C3C', '#9B59B6', '#3498DB', '#E67E22'];
    
    get isDonut() {
        return this.chartType === 'donut';
    }
    
    get isPie() {
        return this.chartType === 'pie';
    }
    
    get isBar() {
        return this.chartType === 'bar';
    }
    
    get isHorizontalBar() {
        return this.chartType === 'horizontalBar';
    }
    
    get isFunnel() {
        return this.chartType === 'funnel';
    }
    
    get isGauge() {
        return this.chartType === 'gauge';
    }
    
    get gaugeValue() {
        return this.chartData?.value || 0;
    }
    
    get gaugeColor() {
        const value = this.gaugeValue;
        if (value >= 80) return '#4BCA81'; // Green
        if (value >= 60) return '#FFB75D'; // Yellow
        return '#E74C3C'; // Red
    }
    
    get gaugeStyle() {
        return `background: conic-gradient(${this.gaugeColor} ${this.gaugeValue * 3.6}deg, #e0e0e0 0deg);`;
    }
    
    get chartItems() {
        if (!this.chartData || !this.chartData.labels || !this.chartData.datasets) {
            return [];
        }
        
        const labels = this.chartData.labels;
        const data = this.chartData.datasets[0].data;
        const total = data.reduce((sum, val) => sum + val, 0);
        const maxValue = Math.max(...data);
        
        return labels.map((label, index) => {
            const value = data[index];
            const percentage = total > 0 ? Math.round((value / total) * 100) : 0;
            const barWidth = maxValue > 0 ? Math.round((value / maxValue) * 100) : 0;
            const color = this.chartData.datasets[0].backgroundColor?.[index] || this.colors[index % this.colors.length];
            
            return {
                label: label,
                value: value,
                displayValue: this.formatValue(value),
                percentage: percentage,
                colorStyle: `background-color: ${color}; width: 20px; height: 20px; display: inline-block; border-radius: 3px;`,
                barStyle: `width: ${barWidth}%; background-color: ${color};`
            };
        });
    }
    
    get stackedChartData() {
        if (!this.chartData || !this.chartData.labels || !this.chartData.datasets) {
            return [];
        }
        
        const labels = this.chartData.labels;
        const datasets = this.chartData.datasets;
        
        // Calculate max total for each label
        const totals = labels.map((_, labelIndex) => {
            return datasets.reduce((sum, dataset) => sum + (dataset.data[labelIndex] || 0), 0);
        });
        const maxTotal = Math.max(...totals);
        
        return labels.map((label, labelIndex) => {
            const segments = datasets.map((dataset, datasetIndex) => {
                const value = dataset.data[labelIndex] || 0;
                const percentage = maxTotal > 0 ? (value / maxTotal) * 100 : 0;
                return {
                    label: dataset.label,
                    value: value,
                    displayValue: this.formatValue(value),
                    percentage: percentage,
                    color: dataset.backgroundColor || this.colors[datasetIndex % this.colors.length],
                    style: `width: ${percentage}%; background-color: ${dataset.backgroundColor || this.colors[datasetIndex % this.colors.length]};`
                };
            });
            
            return {
                label: label,
                segments: segments,
                total: totals[labelIndex]
            };
        });
    }
    
    get funnelItems() {
        if (!this.chartData || !this.chartData.labels || !this.chartData.datasets) {
            return [];
        }
        
        const labels = this.chartData.labels;
        const data = this.chartData.datasets[0].data;
        const maxValue = Math.max(...data);
        
        return labels.map((label, index) => {
            const value = data[index];
            const width = maxValue > 0 ? Math.round((value / maxValue) * 100) : 0;
            const color = this.chartData.datasets[0].backgroundColor?.[index] || this.colors[index % this.colors.length];
            
            return {
                label: label,
                value: value,
                displayValue: this.formatValue(value),
                width: width,
                style: `width: ${width}%; background-color: ${color}; margin: 5px auto;`
            };
        });
    }
    
    get pieSegments() {
        if (!this.chartData || !this.chartData.labels || !this.chartData.datasets) {
            return [];
        }
        
        const labels = this.chartData.labels;
        const data = this.chartData.datasets[0].data;
        const total = data.reduce((sum, val) => sum + val, 0);
        
        let currentAngle = -90; // Start from top
        const segments = [];
        
        labels.forEach((label, index) => {
            const value = data[index];
            const percentage = total > 0 ? (value / total) : 0;
            const angle = percentage * 360;
            const color = this.chartData.datasets[0].backgroundColor?.[index] || this.colors[index % this.colors.length];
            
            // Calculate path for pie segment
            const startAngle = currentAngle;
            const endAngle = currentAngle + angle;
            
            const x1 = 100 + 90 * Math.cos((Math.PI * startAngle) / 180);
            const y1 = 100 + 90 * Math.sin((Math.PI * startAngle) / 180);
            const x2 = 100 + 90 * Math.cos((Math.PI * endAngle) / 180);
            const y2 = 100 + 90 * Math.sin((Math.PI * endAngle) / 180);
            
            const largeArc = angle > 180 ? 1 : 0;
            
            const path = `M 100 100 L ${x1} ${y1} A 90 90 0 ${largeArc} 1 ${x2} ${y2} Z`;
            
            segments.push({
                label: label,
                path: path,
                color: color
            });
            
            currentAngle = endAngle;
        });
        
        return segments;
    }
    
    formatValue(value) {
        if (value >= 1000000) {
            return '$' + (value / 1000000).toFixed(1) + 'M';
        } else if (value >= 1000) {
            return '$' + (value / 1000).toFixed(0) + 'K';
        }
        return value.toString();
    }
    
    handleChartClick(event) {
        const label = event.currentTarget.dataset.label;
        const clickEvent = new CustomEvent('chartclick', {
            detail: { label: label },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(clickEvent);
    }
}