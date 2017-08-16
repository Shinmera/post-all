#|
 This file is a part of post-all
 (c) 2014 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#


(asdf:defsystem post-all
  :name "post-all"
  :version "0.0.1"
  :license "Artistic"
  :author "Nicolas Hafner <shinmera@tymoon.eu>"
  :maintainer "Nicolas Hafner <shinmera@tymoon.eu>"
  :description "Post to multiple services simultaneously."
  :homepage "https://github.com/Shinmera/post-all"
  :serial T
  :components ((:file "post-all"))
  :depends-on (:chirp
               :humbler
               :legit))
