$(document).ready(()=> modeSwitcher() )

if ( !localStorage.getItem('color-theme') ){
	document.documentElement.setAttribute('data-theme', 'dark');
}
else{
	document.documentElement.setAttribute('data-theme', localStorage.getItem('color-theme'));
}

/**
 * Page theme switching between *light* and *dark*
 * 
 * Initialize page theme and set event handlers
 */
function modeSwitcher() {

	updateThemeIcon();

    /*
     * dark-light mode-switcher
     * Swap the sun/moon icon to reflect the active theme
     */
    $('.theme-toggle').off('click').on('click', function(e) {
        e.preventDefault();

		// if exists and set via local storage previously
		if ($(document.documentElement).attr('data-theme') === "dark" ) {
			document.documentElement.setAttribute('data-theme', 'light');
			localStorage.setItem('color-theme', 'light');
		} else {
			document.documentElement.setAttribute('data-theme', 'dark');
			localStorage.setItem('color-theme', 'dark');
		}

		updateThemeIcon();
    });
}

function updateThemeIcon() {
	var isDark = $(document.documentElement).attr('data-theme') === 'dark';
	$('.theme-toggle-icon').toggleClass('fa-moon', isDark).toggleClass('fa-sun', !isDark);
}
