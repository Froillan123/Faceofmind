import { Routes } from '@angular/router';
import { AdminLoginComponent } from './admin-login/admin-login.component';
import { AdminRegisterComponent } from './admin-register/admin-register.component';
import { DashboardComponent } from './dashboard/dashboard.component';

export const routes: Routes = [
  { path: '', component: AdminLoginComponent },
  { path: 'admin/register', component: AdminRegisterComponent },
  { path: 'dashboard', component: DashboardComponent },
  { path: 'admin-login', component: AdminLoginComponent },
  // Catch-all route - redirect to login if route not found
  { path: '**', redirectTo: '', pathMatch: 'full' }
];
