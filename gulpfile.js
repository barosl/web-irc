var gulp = require('gulp');
var plumber = require('gulp-plumber');
var watch = require('gulp-watch');

var coffee = require('gulp-coffee');
var less = require('gulp-less');

gulp.task('js', function() {
    return gulp.src('js/*.coffee')
        .pipe(watch())
        .pipe(plumber())
        .pipe(coffee())
        .pipe(gulp.dest('build/js'));
});

gulp.task('css', function() {
    return gulp.src('css/*.less')
        .pipe(watch())
        .pipe(plumber())
        .pipe(less())
        .pipe(gulp.dest('build/css'));
});

gulp.task('default', ['js', 'css']);
