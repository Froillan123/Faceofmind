import { Routes } from '@angular/router';
import { AdminLoginComponent } from './admin-login/admin-login.component';
import { AdminRegisterComponent } from './admin-register/admin-register.component';

export const routes: Routes = [
  { path: '', component: AdminLoginComponent },
  { path: 'admin/register', component: AdminRegisterComponent },
  // ...other routes
];
