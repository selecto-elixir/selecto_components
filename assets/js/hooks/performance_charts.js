// Performance monitoring chart hooks for SelectoComponents

export const QueryTimeline = {
  mounted() {
    this.chart = null;
    this.initChart();
    this.handleEvent("update-timeline", (data) => this.updateChart(data));
  },

  initChart() {
    const canvas = this.el.querySelector('#timeline-canvas');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    
    // Create timeline visualization
    this.chart = {
      canvas: canvas,
      ctx: ctx,
      data: [],
      timeWindow: 5 * 60 * 1000, // 5 minutes default
      
      render() {
        const width = canvas.width = canvas.offsetWidth;
        const height = canvas.height = canvas.offsetHeight;
        
        // Clear canvas
        ctx.clearRect(0, 0, width, height);
        
        // Draw grid
        this.drawGrid(width, height);
        
        // Draw timeline bars
        this.drawQueries(width, height);
        
        // Draw axes
        this.drawAxes(width, height);
      },
      
      drawGrid(width, height) {
        ctx.strokeStyle = '#e5e7eb';
        ctx.lineWidth = 1;
        
        // Horizontal lines
        for (let i = 0; i <= 5; i++) {
          const y = (height / 5) * i;
          ctx.beginPath();
          ctx.moveTo(0, y);
          ctx.lineTo(width, y);
          ctx.stroke();
        }
        
        // Vertical lines (time markers)
        for (let i = 0; i <= 10; i++) {
          const x = (width / 10) * i;
          ctx.beginPath();
          ctx.moveTo(x, 0);
          ctx.lineTo(x, height);
          ctx.stroke();
        }
      },
      
      drawQueries(width, height) {
        const now = Date.now();
        const startTime = now - this.timeWindow;
        
        this.data.forEach(query => {
          const x = ((query.timestamp - startTime) / this.timeWindow) * width;
          const barHeight = Math.min((query.duration / 1000) * height, height - 20);
          const y = height - barHeight;
          
          // Choose color based on duration
          if (query.duration < 50) {
            ctx.fillStyle = '#10b981'; // green
          } else if (query.duration < 200) {
            ctx.fillStyle = '#f59e0b'; // yellow
          } else {
            ctx.fillStyle = '#ef4444'; // red
          }
          
          // Draw bar
          ctx.fillRect(x - 2, y, 4, barHeight);
          
          // Draw tooltip on hover
          if (this.hoveredQuery === query) {
            this.drawTooltip(x, y, query);
          }
        });
      },
      
      drawAxes(width, height) {
        ctx.strokeStyle = '#374151';
        ctx.lineWidth = 2;
        
        // Y-axis
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(0, height);
        ctx.stroke();
        
        // X-axis
        ctx.beginPath();
        ctx.moveTo(0, height);
        ctx.lineTo(width, height);
        ctx.stroke();
        
        // Labels
        ctx.fillStyle = '#6b7280';
        ctx.font = '11px sans-serif';
        
        // Y-axis labels (duration)
        ctx.textAlign = 'right';
        for (let i = 0; i <= 5; i++) {
          const value = (1000 / 5) * (5 - i);
          const y = (height / 5) * i;
          ctx.fillText(`${value}ms`, -5, y + 4);
        }
        
        // X-axis labels (time)
        ctx.textAlign = 'center';
        const now = new Date();
        for (let i = 0; i <= 5; i++) {
          const time = new Date(now - (this.timeWindow / 5) * (5 - i));
          const x = (width / 5) * i;
          ctx.fillText(time.toLocaleTimeString(), x, height + 15);
        }
      },
      
      drawTooltip(x, y, query) {
        const text = `${query.duration}ms - ${query.rows} rows`;
        const padding = 5;
        const metrics = ctx.measureText(text);
        const tooltipWidth = metrics.width + padding * 2;
        const tooltipHeight = 20;
        
        // Background
        ctx.fillStyle = 'rgba(31, 41, 55, 0.9)';
        ctx.fillRect(x - tooltipWidth / 2, y - tooltipHeight - 5, tooltipWidth, tooltipHeight);
        
        // Text
        ctx.fillStyle = 'white';
        ctx.font = '11px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(text, x, y - 10);
      },
      
      addQuery(query) {
        this.data.push(query);
        // Keep only queries within time window
        const cutoff = Date.now() - this.timeWindow;
        this.data = this.data.filter(q => q.timestamp > cutoff);
        this.render();
      }
    };
    
    // Initial render
    this.chart.render();
    
    // Handle resize
    window.addEventListener('resize', () => this.chart.render());
    
    // Handle mouse events for tooltips
    canvas.addEventListener('mousemove', (e) => {
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      // Find query under cursor
      const now = Date.now();
      const startTime = now - this.chart.timeWindow;
      
      this.chart.hoveredQuery = this.chart.data.find(query => {
        const qx = ((query.timestamp - startTime) / this.chart.timeWindow) * canvas.width;
        return Math.abs(qx - x) < 5;
      });
      
      this.chart.render();
    });
  },

  updateChart(data) {
    if (this.chart) {
      data.queries.forEach(q => this.chart.addQuery(q));
    }
  },

  destroyed() {
    // Cleanup
    window.removeEventListener('resize', () => this.chart.render());
  }
};

export const CacheHitRateChart = {
  mounted() {
    this.chart = null;
    this.history = [];
    this.maxPoints = 60; // Keep last 60 data points
    
    this.initChart();
    this.handleEvent("update-cache-stats", (data) => this.updateChart(data));
  },

  initChart() {
    const canvas = this.el.querySelector('#cache-chart-canvas');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    
    this.chart = {
      canvas: canvas,
      ctx: ctx,
      
      render() {
        const width = canvas.width = canvas.offsetWidth;
        const height = canvas.height = canvas.offsetHeight;
        
        ctx.clearRect(0, 0, width, height);
        
        if (this.history.length < 2) return;
        
        // Draw background grid
        ctx.strokeStyle = '#e5e7eb';
        ctx.lineWidth = 0.5;
        
        for (let i = 0; i <= 10; i++) {
          const y = (height / 10) * i;
          ctx.beginPath();
          ctx.moveTo(0, y);
          ctx.lineTo(width, y);
          ctx.stroke();
        }
        
        // Draw hit rate line
        ctx.strokeStyle = '#10b981';
        ctx.lineWidth = 2;
        ctx.beginPath();
        
        this.history.forEach((point, index) => {
          const x = (index / (this.maxPoints - 1)) * width;
          const y = height - (point.hitRate / 100) * height;
          
          if (index === 0) {
            ctx.moveTo(x, y);
          } else {
            ctx.lineTo(x, y);
          }
        });
        
        ctx.stroke();
        
        // Fill area under curve
        ctx.fillStyle = 'rgba(16, 185, 129, 0.1)';
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fill();
        
        // Draw current value
        if (this.history.length > 0) {
          const current = this.history[this.history.length - 1];
          ctx.fillStyle = '#374151';
          ctx.font = 'bold 24px sans-serif';
          ctx.textAlign = 'center';
          ctx.fillText(`${current.hitRate.toFixed(1)}%`, width / 2, height / 2);
        }
        
        // Draw scale
        ctx.fillStyle = '#6b7280';
        ctx.font = '10px sans-serif';
        ctx.textAlign = 'right';
        ctx.fillText('100%', width - 5, 15);
        ctx.fillText('0%', width - 5, height - 5);
      }
    };
    
    // Bind this context
    this.chart.history = this.history;
    this.chart.maxPoints = this.maxPoints;
    
    // Initial render
    this.chart.render();
    
    // Update periodically with mock data for demo
    this.interval = setInterval(() => {
      // In production, this would come from server events
      const mockData = {
        hitRate: 70 + Math.random() * 20,
        timestamp: Date.now()
      };
      this.addDataPoint(mockData);
    }, 2000);
  },

  addDataPoint(data) {
    this.history.push(data);
    if (this.history.length > this.maxPoints) {
      this.history.shift();
    }
    this.chart.history = this.history;
    this.chart.render();
  },

  updateChart(data) {
    this.addDataPoint(data);
  },

  destroyed() {
    if (this.interval) {
      clearInterval(this.interval);
    }
  }
};

// Export hooks
export const PerformanceHooks = {
  QueryTimeline,
  CacheHitRateChart
};