#|
 This file is a part of post-all
 (c) 2014 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(defpackage #:post-all
  (:nicknames #:org.shirakumo.post-all)
  (:use #:cl)
  (:export
   #:*config*
   #:*twitter-api-key*
   #:*twitter-api-secret*
   #:*tumblr-api-key*
   #:*tumblr-api-secret*
   
   #:login-twitter
   #:login-tumblr
   #:login

   #:save-config
   #:load-config
   #:setup
   #:twitter-photo
   #:tumblr-photo
   #:git-photo
   #:post-photo
   #:twitter-link
   #:tumblr-link
   #:post-link))
(in-package #:post-all)

(defvar *config* #p"~/.shirakumo/post-all")
(defvar *twitter-api-key*)
(defvar *twitter-api-secret*)
(defvar *tumblr-api-key*)
(defvar *tumblr-api-secret*)

;;;;;
;; Login and Config

(defun login-twitter ()
  (format T "~&Beginning Twitter login.~%")
  (let ((url (chirp:initiate-authentication :api-key *twitter-api-key* :api-secret *twitter-api-secret*)))
    (format T "~&Please visit  ~a  and enter the PIN: "
            url)
    (let ((pin (read-line)))
      (chirp:complete-authentication pin)
      (chirp:account/verify-credentials)))
  (format T "~&Twitter successfully set up.~%")
  (list chirp:*oauth-access-token*
        chirp:*oauth-access-secret*))

(defun login-tumblr ()
  (format T "~&Beginning Tumblr login.~%")
  (south:prepare :api-key *tumblr-api-key* :api-secret *tumblr-api-secret*)
  (let ((url (humbler:login)))
    (format T "~&Please visit  ~a  .~%" url)
    (loop until humbler:*user*
          do (sleep 1)))
  (format T "~&Tumblr successfully set up.~%")
  (list south:*oauth-access-token*
        south:*oauth-access-secret*))

(defun login ()
  (login-twitter)
  (login-tumblr)
  T)

(defun save-config ()
  (format T "~&Saving config to ~s~%" *config*)
  (ensure-directories-exist *config*)
  (with-open-file (stream *config* :direction :output :if-exists :supersede :if-does-not-exist :create)
    (let ((*print-readably* T)
          (*print-pretty* T))
      (print (list :twitter (list :access-token chirp:*oauth-access-token*
                                  :access-secret chirp:*oauth-access-secret*
                                  :api-key chirp:*oauth-api-key*
                                  :api-secret chirp:*oauth-api-secret*)
                   :tumblr (list :access-token south:*oauth-access-token*
                                 :access-secret south:*oauth-access-secret*
                                 :api-key south:*oauth-api-key*
                                 :api-secret south:*oauth-api-secret*))
             stream)))
  *config*)

(defun load-config ()
  (format T "~&Loading config from ~s~%" *config*)
  (with-open-file (stream *config* :direction :input :if-does-not-exist :error)
    (destructuring-bind (&key twitter tumblr) (read stream)
      (setf chirp:*oauth-access-token* (getf twitter :access-token)
            chirp:*oauth-access-secret* (getf twitter :access-secret)
            chirp:*oauth-api-key* (getf twitter :api-key)
            chirp:*oauth-api-secret* (getf twitter :api-secret)
            *twitter-api-key* (getf twitter :api-key)
            *twitter-api-secret* (getf twitter :api-secret))
      (setf south:*oauth-access-token* (getf tumblr :access-token)
            south:*oauth-access-secret* (getf tumblr :access-secret)
            south:*oauth-api-key* (getf tumblr :api-key)
            south:*oauth-api-secret* (getf tumblr :api-secret)
            *tumblr-api-key* (getf tumblr :api-key)
            *tumblr-api-secret* (getf tumblr :api-secret))))
  *config*)

(defun setup ()
  (or (ignore-errors (load-config))
      (login))
  (setf humbler:*user* (or humbler:*user*
                           (humbler:myself))))

(defun ensure-set-up ()
  (unless humbler:*user*
    (setup)))

(defun limit-text (text length)
  (if (<= (length text) length)
      text
      (concatenate 'string (subseq text 0 (- length 3)) "...")))

;;;;;
;; Actual posting stuff

(defun twitter-photo (picture text)
  (format T "~&Posting ~s ~s to twitter...~%" picture text)
  (chirp:statuses/update-with-media text picture))

(defun tumblr-photo (picture text &key tags)
  (format T "~&Posting ~s ~s ~s to tumblr...~%" picture text tags)
  (humbler:blog/post-photo (humbler:name humbler:*user*) picture :caption text :tags tags :tweet :off))

(defun git-photo (picture text &key tags)
  (when (legit:git-location-p
         (uiop:pathname-directory-pathname picture))
    (let ((repo (legit:init (uiop:pathname-directory-pathname picture))))
      (legit:add repo picture)
      (legit:commit repo (format NIL "~a~%~%Tags: ~{~a~^, ~}" text tags))
      (legit:push repo))))

(defun post-photo (picture text &key tags)
  (ensure-set-up)
  (let* ((url (format NIL "~apost/~a/" (humbler:url humbler:*user*) (tumblr-photo picture text :tags tags)))
         (maxlength (- 140
                       2 ; For the spaces in-between.
                       (chirp:short-url-length-https (chirp:help/configuration))
                       (chirp:characters-reserved-per-media (chirp:help/configuration)))))
    (twitter-photo picture (format NIL "~a ~a" (limit-text text maxlength) url))
    (git-photo picture (format NIL "~a~%~a" text url) :tags tags)))

(defun twitter-link (url text)
  (format T "~&Posting ~s ~s to twitter...~%" url text)
  (let ((maxlength (- 140 2 (chirp:short-url-length-https (chirp:help/configuration)))))
    (chirp:statuses/update (format NIL "~a~%~a" (limit-text text maxlength) url))))

(defun tumblr-link (url text &key tags title)
  (format T "~&Posting ~s~@[ (~s)~] ~s ~s to tumblr...~%" url title text tags)
  (humbler:blog/post-link (humbler:name humbler:*user*) url :description text :title title :tags tags))

(defun post-link (url text &key title tags)
  (ensure-set-up)
  (tumblr-link url text :title title :tags tags)
  (twitter-link url text))
