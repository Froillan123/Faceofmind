import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../services/auth.service';
import { BaseChartDirective } from 'ng2-charts';
import { ChartConfiguration, ChartType } from 'chart.js';
import { catchError, finalize } from 'rxjs/operators';
import { of } from 'rxjs';

interface AnalyticsData {
  labels: string[];
  data_all: number[];
  data_admin: number[];
  data_professional: number[];
  data_user: number[];
  total_users: number;
  new_users: number;
  admin_count: number;
  professional_count: number;
  regular_count: number;
  start_date: string;
  end_date: string;
  period: string;
  group_by: string;
}

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterModule, BaseChartDirective],
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.css']
})
export class DashboardComponent implements OnInit {
  analytics: AnalyticsData | null = null;
  loading = true;
  error = '';
  lastFetchTime: number | null = null;
  cacheKey = '';

  filter: 'week' | 'month' | 'year' = 'week';
  chartType: ChartType = 'bar';
  
  chartDataAll: ChartConfiguration['data'] = { labels: [], datasets: [] };
  chartDataAdmin: ChartConfiguration['data'] = { labels: [], datasets: [] };
  chartDataProfessional: ChartConfiguration['data'] = { labels: [], datasets: [] };
  chartDataUser: ChartConfiguration['data'] = { labels: [], datasets: [] };

  chartOptions: ChartConfiguration['options'] = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { 
        display: true,
        position: 'top',
        labels: {
          usePointStyle: true,
          padding: 20,
          font: { size: 12 }
        }
      },
      tooltip: {
        enabled: true,
        mode: 'index',
        intersect: false,
        bodyFont: { size: 12 }
      }
    },
    scales: {
      x: {
        grid: { display: false },
        ticks: { font: { size: 11 } }
      },
      y: { 
        beginAtZero: true,
        ticks: {
          precision: 0,
          font: { size: 11 }
        }
      }
    },
    animation: {
      duration: 800,
      easing: 'easeOutQuart'
    }
  };

  allTimeCounts: { total: number, admin: number, professional: number, regular: number } = { total: 0, admin: 0, professional: 0, regular: 0 };

  constructor(
    private http: HttpClient,
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    if (!this.authService.isLoggedIn()) {
      this.router.navigate(['/']);
      return;
    }
    this.fetchAllTimeCounts();
    this.fetchAnalytics();
  }

  setFilter(filter: 'week' | 'month' | 'year'): void {
    if (this.filter !== filter) {
      this.filter = filter;
      this.fetchAnalytics();
    }
  }

  fetchAnalytics(): void {
    this.cacheKey = `analytics_${this.filter}`;
    const cachedData = this.getCachedData();
    const now = Date.now();
    
    if (cachedData && this.lastFetchTime && (now - this.lastFetchTime < 300000)) {
      this.processAnalyticsData(cachedData);
      return;
    }

    this.loading = true;
    this.error = '';
    
    this.http.get<AnalyticsData>(`/api/user-analytics/?period=${this.filter}`)
      .pipe(
        catchError(err => {
          console.error('Error fetching analytics:', err);
          this.error = 'Failed to load analytics. Please try again.';
          return of(null);
        }),
        finalize(() => {
          this.loading = false;
        })
      )
      .subscribe({
        next: (data) => {
          if (data) {
            this.lastFetchTime = Date.now();
            this.cacheData(data);
            this.processAnalyticsData(data);
          }
        }
      });
  }

  fetchAllTimeCounts(): void {
    this.http.get<AnalyticsData>('/api/user-analytics/?period=week').pipe(
      catchError(() => of(null))
    ).subscribe((data) => {
      if (data) {
        this.allTimeCounts.total = data.total_users;
        this.allTimeCounts.admin = data.admin_count;
        this.allTimeCounts.professional = data.professional_count;
        this.allTimeCounts.regular = data.regular_count;
      }
    });
  }

  private processAnalyticsData(data: AnalyticsData): void {
    this.analytics = data;
    
    // Format labels based on period
    let formattedLabels = [...data.labels];
    
    if (this.filter === 'month') {
      formattedLabels = ['Week 1', 'Week 2', 'Week 3', 'Week 4'];
    } else if (this.filter === 'year') {
      formattedLabels = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
    }

    const commonOptions = {
      borderWidth: 1,
      borderRadius: 4,
      borderSkipped: false,
    };

    this.chartDataAll = {
      labels: formattedLabels,
      datasets: [
        {
          data: data.data_all,
          label: 'All Users',
          backgroundColor: '#1890ff80',
          borderColor: '#1890ff',
          ...commonOptions
        }
      ]
    };

    this.chartDataAdmin = {
      labels: formattedLabels,
      datasets: [
        {
          data: data.data_admin,
          label: 'Admins',
          backgroundColor: '#2980b980',
          borderColor: '#2980b9',
          ...commonOptions
        }
      ]
    };

    this.chartDataProfessional = {
      labels: formattedLabels,
      datasets: [
        {
          data: data.data_professional,
          label: 'Professionals',
          backgroundColor: '#16a08580',
          borderColor: '#16a085',
          ...commonOptions
        }
      ]
    };

    this.chartDataUser = {
      labels: formattedLabels,
      datasets: [
        {
          data: data.data_user,
          label: 'Regular Users',
          backgroundColor: '#52c41a80',
          borderColor: '#52c41a',
          ...commonOptions
        }
      ]
    };
  }

  private cacheData(data: AnalyticsData): void {
    try {
      localStorage.setItem(this.cacheKey, JSON.stringify({
        timestamp: Date.now(),
        data: data
      }));
    } catch (e) {
      console.warn('Failed to cache analytics data', e);
    }
  }

  private getCachedData(): AnalyticsData | null {
    try {
      const cached = localStorage.getItem(this.cacheKey);
      if (cached) {
        const parsed = JSON.parse(cached);
        if (parsed && parsed.data) {
          return parsed.data;
        }
      }
    } catch (e) {
      console.warn('Failed to read cached analytics data', e);
    }
    return null;
  }

  logout(): void {
    this.authService.logout();
    this.router.navigate(['/']);
  }
}