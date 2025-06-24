import { Component } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { Router, RouterModule } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-admin-register',
  templateUrl: './admin-register.component.html',
  styleUrls: ['./admin-register.component.css'],
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, RouterModule]
})
export class AdminRegisterComponent {
  registerForm: FormGroup;
  loading = false;
  errorMessage = '';
  successMessage = '';
  showPassword = false;
  passwordErrors: string[] = [];

  constructor(private fb: FormBuilder, private http: HttpClient, private router: Router) {
    this.registerForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [
        Validators.required,
        Validators.minLength(8),
        this.hasNumberValidator(),
        this.hasSpecialCharValidator(),
        this.hasUpperCaseValidator()
      ]],
      first_name: ['', Validators.required],
      last_name: ['', Validators.required]
    });

    this.registerForm.get('password')?.valueChanges.subscribe(() => {
      this.updatePasswordErrors();
    });
  }

  togglePasswordVisibility(): void {
    this.showPassword = !this.showPassword;
    const passwordField = document.getElementById('password');
    if (passwordField) {
      passwordField.focus();
    }
  }

  hasNumber(): boolean {
    const password = this.registerForm.get('password')?.value;
    return password && /\d/.test(password);
  }

  hasSpecialChar(): boolean {
    const password = this.registerForm.get('password')?.value;
    return password && /[!@#$%^&*(),.?":{}|<>]/.test(password);
  }

  hasUpperCase(): boolean {
    const password = this.registerForm.get('password')?.value;
    return password && /[A-Z]/.test(password);
  }

  updatePasswordErrors(): void {
    this.passwordErrors = [];
    const password = this.registerForm.get('password')?.value;
    
    if (!password) return;

    if (password.length < 8) {
      this.passwordErrors.push('At least 8 characters');
    }
    if (!/\d/.test(password)) {
      this.passwordErrors.push('At least 1 number');
    }
    if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
      this.passwordErrors.push('At least 1 special character');
    }
    if (!/[A-Z]/.test(password)) {
      this.passwordErrors.push('At least 1 uppercase letter');
    }
  }

  hasNumberValidator() {
    return (control: { value: string }) => {
      const hasNumber = /\d/.test(control.value);
      return hasNumber ? null : { hasNumber: true };
    };
  }

  hasSpecialCharValidator() {
    return (control: { value: string }) => {
      const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(control.value);
      return hasSpecialChar ? null : { hasSpecialChar: true };
    };
  }

  hasUpperCaseValidator() {
    return (control: { value: string }) => {
      const hasUpperCase = /[A-Z]/.test(control.value);
      return hasUpperCase ? null : { hasUpperCase: true };
    };
  }

  onSubmit(): void {
    if (this.registerForm.invalid) {
      this.registerForm.markAllAsTouched();
      return;
    }

    this.loading = true;
    this.errorMessage = '';
    this.successMessage = '';
    
    this.http.post('/api/Admin_register/', this.registerForm.value).subscribe({
      next: () => {
        this.successMessage = 'Admin registered successfully!';
        this.loading = false;
        setTimeout(() => this.router.navigate(['/']), 1500);
      },
      error: (error) => {
        this.loading = false;
        this.errorMessage = error?.error?.message || 
                          error?.error?.error || 
                          error.message || 
                          'Registration failed. Please try again.';
        console.error('Registration error:', error);
      }
    });
  }
}