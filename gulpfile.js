var gulp = require('gulp');
var plumber = require('gulp-plumber');
var newer = require('gulp-newer');

var coffee = require('gulp-coffee');
var less = require('gulp-less');

var srcs = {
    js: 'js/*.coffee',
    css: 'css/*.less'
};

var dests = {
    js: 'build/js',
    css: 'build/css'
};

gulp.task('js', function() {
    return gulp.src(srcs.js)
        .pipe(newer(dests.js))
        .pipe(plumber())
        .pipe(coffee())
        .pipe(gulp.dest(dests.js));
});

gulp.task('css', function() {
    return gulp.src(srcs.css)
        .pipe(newer(dests.css))
        .pipe(plumber())
        .pipe(less())
        .pipe(gulp.dest(dests.css));
});

gulp.task('watch', function() {
    gulp.watch(srcs.js, ['js']);
    gulp.watch(srcs.css, ['css']);
});

gulp.task('default', ['js', 'css', 'watch']);
