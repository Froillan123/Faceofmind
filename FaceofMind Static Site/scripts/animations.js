// Scroll animation trigger
function animateOnScroll() {
    const elements = document.querySelectorAll('.animate-on-scroll');
    
    elements.forEach(element => {
        const elementPosition = element.getBoundingClientRect().top;
        const screenPosition = window.innerHeight / 1.2;
        
        if (elementPosition < screenPosition) {
            element.classList.add('animated');
        }
    });
}

window.addEventListener('scroll', animateOnScroll);
animateOnScroll(); // Run once on load

// Parallax effect for hero image
function parallaxEffect() {
    const heroImage = document.querySelector('.hero-image');
    if (heroImage) {
        const scrollPosition = window.pageYOffset;
        heroImage.style.transform = `translateY(${scrollPosition * 0.2}px)`;
    }
}

window.addEventListener('scroll', parallaxEffect);

// Feature card hover animation
/*
const featureCards = document.querySelectorAll('.feature-card');
featureCards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const x = e.clientX - card.getBoundingClientRect().left;
        const y = e.clientY - card.getBoundingClientRect().top;
        
        const centerX = card.offsetWidth / 2;
        const centerY = card.offsetHeight / 2;
        
        const angleX = (y - centerY) / 10;
        const angleY = (centerX - x) / 10;
        
        card.style.transform = `perspective(1000px) rotateX(${angleX}deg) rotateY(${angleY}deg)`;
    });
    
    card.addEventListener('mouseleave', () => {
        card.style.transform = 'perspective(1000px) rotateX(0) rotateY(0)';
    });
});
*/

// Form submission handling
const waitlistForm = document.querySelector('.waitlist-form');
if (waitlistForm) {
    waitlistForm.addEventListener('submit', function(e) {
        e.preventDefault();
        const emailInput = this.querySelector('input[type="email"]');
        
        // Simple validation
        if (emailInput.value && emailInput.value.includes('@')) {
            // In a real app, you would send this to your server
            alert('Thanks for joining the waitlist! We\'ll notify you when FaceofMind is ready.');
            emailInput.value = '';
        } else {
            alert('Please enter a valid email address.');
        }
    });
}