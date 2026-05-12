(in-package :taf.core)

;;;; ============================================================
;;;; project / new.lisp
;;;; ============================================================

(defun %error-diagnostic-p (diagnostic)
  (eql :error (han.args:arg-diagnostic-kind diagnostic)))

(defun %check-args-result (args-result)
  (dolist (diagnostic (han.args:args-result-diagnostics args-result))
    (when (%error-diagnostic-p diagnostic)
      (error "~A" (han.args:arg-diagnostic-message diagnostic))))
  args-result)

;;;; taffish.toml
(defparameter *default-container-platforms*
  "linux/amd64,linux/arm64")

(defparameter *default-smoke-timeout*
  60)

(defun %make-smoke-toml-lines ()
  (list "[smoke]"
        "backend = \"docker\""
        (format nil "timeout = ~A" *default-smoke-timeout*)
        "exist = [\"TODO\"]"
        "test = [\"TODO --help\"]"
        ""))

(defun %make-taffish-toml-string
    (name tool-or-flow version release license repository-url image docker-p)
  (let ((container-p (or image docker-p)))
    (format nil "~{~A~^~%~}"
            (append
             (list "[package]"
                   (format nil "name = \"~A\"" name)
                   (format nil "kind = \"~A\"" (case tool-or-flow
                                                 (:tool "tool")
                                                 (:flow "flow")))
                   (format nil "version = \"~A\"" version)
                   (format nil "release = ~A" release)
                   (format nil "license = \"~A\"" license)
                   "main = \"src/main.taf\""
                   ""
                   "[repository]"
                   (format nil "url = \"~A\"" repository-url)
                   ""
                   "[command]"
                   (format nil "name = \"taf-~A\"" name)
                   "")
             (case tool-or-flow
               (:tool '("[runtime]"
                        "pipe = true"
                        "command_mode = true"
                        ""))
               (:flow '("[runtime]"
                        "pipe = false"
                        "command_mode = false"
                        "")))
             (when container-p
               (list "[container]"))
             (if (and container-p image)
                 (list (format nil "image = \"~A\"" image)))
             (when (and container-p docker-p)
               (list "dockerfile = \"docker/Dockerfile\""))
             (when (and container-p docker-p)
               (list (format nil "build_platforms = \"~A\""
                             *default-container-platforms*)))
             (when container-p
               (list ""))
             (when container-p
               (%make-smoke-toml-lines))))))

;;;; src/main.taf
(defun %make-src-main-flow-string (name version)
  (format nil "<taffish>~%echo '<flow>[~A: ~A] Hello, World!'" name version))

(defun %make-src-main-tool-string (name version image)
  (format nil "<taf-app:~A>~%echo '<tool>[~A: ~A] Hello, World!'"
          (if image (format nil "container:~A" image) "shell")
          name version))

(defun %make-src-main-string (name tool-or-flow version image)
  (case tool-or-flow
    (:flow (%make-src-main-flow-string name version))
    (:tool (%make-src-main-tool-string name version image))))

;; DOCKERFILE
(defun %make-dockerfile-string (name)
  (format nil "FROM ~A

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \\
 && apt-get install -y --no-install-recommends \\
      ca-certificates \\
      curl \\
      git \\
      build-essential \\
 && rm -rf /var/lib/apt/lists/*

WORKDIR /root

ENV TAFFISH_ENV=TAFFISH
ENV TAFFISH_NAME=~A"
          (%default-base-container-image)
          name))

;;;; README.md
(defun %make-readme-string (name)
  (format nil "# ~A~%~%A TAFFISH app project.~%" name))

;;;; LICENSE
(defun %normalize-license-id (license)
  (cond
    ((or (null license)
         (string-equal license "Apache-2.0")
         (string-equal license "Apache"))
     "Apache-2.0")
    (t
     (error "[new] unsupported license: ~S. Supported license template: Apache-2.0"
            license))))

(defun %make-apache-2.0-license-string ()
  (format nil "~{~A~%~}"
          '("                                 Apache License"
            "                           Version 2.0, January 2004"
            "                        http://www.apache.org/licenses/"
            ""
            "   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION"
            ""
            "   1. Definitions."
            ""
            "      \"License\" shall mean the terms and conditions for use, reproduction,"
            "      and distribution as defined by Sections 1 through 9 of this document."
            ""
            "      \"Licensor\" shall mean the copyright owner or entity authorized by"
            "      the copyright owner that is granting the License."
            ""
            "      \"Legal Entity\" shall mean the union of the acting entity and all"
            "      other entities that control, are controlled by, or are under common"
            "      control with that entity. For the purposes of this definition,"
            "      \"control\" means (i) the power, direct or indirect, to cause the"
            "      direction or management of such entity, whether by contract or"
            "      otherwise, or (ii) ownership of fifty percent (50%) or more of the"
            "      outstanding shares, or (iii) beneficial ownership of such entity."
            ""
            "      \"You\" (or \"Your\") shall mean an individual or Legal Entity"
            "      exercising permissions granted by this License."
            ""
            "      \"Source\" form shall mean the preferred form for making modifications,"
            "      including but not limited to software source code, documentation"
            "      source, and configuration files."
            ""
            "      \"Object\" form shall mean any form resulting from mechanical"
            "      transformation or translation of a Source form, including but"
            "      not limited to compiled object code, generated documentation,"
            "      and conversions to other media types."
            ""
            "      \"Work\" shall mean the work of authorship, whether in Source or"
            "      Object form, made available under the License, as indicated by a"
            "      copyright notice that is included in or attached to the work"
            "      (an example is provided in the Appendix below)."
            ""
            "      \"Derivative Works\" shall mean any work, whether in Source or Object"
            "      form, that is based on (or derived from) the Work and for which the"
            "      editorial revisions, annotations, elaborations, or other modifications"
            "      represent, as a whole, an original work of authorship. For the purposes"
            "      of this License, Derivative Works shall not include works that remain"
            "      separable from, or merely link (or bind by name) to the interfaces of,"
            "      the Work and Derivative Works thereof."
            ""
            "      \"Contribution\" shall mean any work of authorship, including"
            "      the original version of the Work and any modifications or additions"
            "      to that Work or Derivative Works thereof, that is intentionally"
            "      submitted to Licensor for inclusion in the Work by the copyright owner"
            "      or by an individual or Legal Entity authorized to submit on behalf of"
            "      the copyright owner. For the purposes of this definition, \"submitted\""
            "      means any form of electronic, verbal, or written communication sent"
            "      to the Licensor or its representatives, including but not limited to"
            "      communication on electronic mailing lists, source code control systems,"
            "      and issue tracking systems that are managed by, or on behalf of, the"
            "      Licensor for the purpose of discussing and improving the Work, but"
            "      excluding communication that is conspicuously marked or otherwise"
            "      designated in writing by the copyright owner as \"Not a Contribution.\""
            ""
            "      \"Contributor\" shall mean Licensor and any individual or Legal Entity"
            "      on behalf of whom a Contribution has been received by Licensor and"
            "      subsequently incorporated within the Work."
            ""
            "   2. Grant of Copyright License. Subject to the terms and conditions of"
            "      this License, each Contributor hereby grants to You a perpetual,"
            "      worldwide, non-exclusive, no-charge, royalty-free, irrevocable"
            "      copyright license to reproduce, prepare Derivative Works of,"
            "      publicly display, publicly perform, sublicense, and distribute the"
            "      Work and such Derivative Works in Source or Object form."
            ""
            "   3. Grant of Patent License. Subject to the terms and conditions of"
            "      this License, each Contributor hereby grants to You a perpetual,"
            "      worldwide, non-exclusive, no-charge, royalty-free, irrevocable"
            "      (except as stated in this section) patent license to make, have made,"
            "      use, offer to sell, sell, import, and otherwise transfer the Work,"
            "      where such license applies only to those patent claims licensable"
            "      by such Contributor that are necessarily infringed by their"
            "      Contribution(s) alone or by combination of their Contribution(s)"
            "      with the Work to which such Contribution(s) was submitted. If You"
            "      institute patent litigation against any entity (including a"
            "      cross-claim or counterclaim in a lawsuit) alleging that the Work"
            "      or a Contribution incorporated within the Work constitutes direct"
            "      or contributory patent infringement, then any patent licenses"
            "      granted to You under this License for that Work shall terminate"
            "      as of the date such litigation is filed."
            ""
            "   4. Redistribution. You may reproduce and distribute copies of the"
            "      Work or Derivative Works thereof in any medium, with or without"
            "      modifications, and in Source or Object form, provided that You"
            "      meet the following conditions:"
            ""
            "      (a) You must give any other recipients of the Work or"
            "          Derivative Works a copy of this License; and"
            ""
            "      (b) You must cause any modified files to carry prominent notices"
            "          stating that You changed the files; and"
            ""
            "      (c) You must retain, in the Source form of any Derivative Works"
            "          that You distribute, all copyright, patent, trademark, and"
            "          attribution notices from the Source form of the Work,"
            "          excluding those notices that do not pertain to any part of"
            "          the Derivative Works; and"
            ""
            "      (d) If the Work includes a \"NOTICE\" text file as part of its"
            "          distribution, then any Derivative Works that You distribute must"
            "          include a readable copy of the attribution notices contained"
            "          within such NOTICE file, excluding those notices that do not"
            "          pertain to any part of the Derivative Works, in at least one"
            "          of the following places: within a NOTICE text file distributed"
            "          as part of the Derivative Works; within the Source form or"
            "          documentation, if provided along with the Derivative Works; or,"
            "          within a display generated by the Derivative Works, if and"
            "          wherever such third-party notices normally appear. The contents"
            "          of the NOTICE file are for informational purposes only and"
            "          do not modify the License. You may add Your own attribution"
            "          notices within Derivative Works that You distribute, alongside"
            "          or as an addendum to the NOTICE text from the Work, provided"
            "          that such additional attribution notices cannot be construed"
            "          as modifying the License."
            ""
            "      You may add Your own copyright statement to Your modifications and"
            "      may provide additional or different license terms and conditions"
            "      for use, reproduction, or distribution of Your modifications, or"
            "      for any such Derivative Works as a whole, provided Your use,"
            "      reproduction, and distribution of the Work otherwise complies with"
            "      the conditions stated in this License."
            ""
            "   5. Submission of Contributions. Unless You explicitly state otherwise,"
            "      any Contribution intentionally submitted for inclusion in the Work"
            "      by You to the Licensor shall be under the terms and conditions of"
            "      this License, without any additional terms or conditions."
            "      Notwithstanding the above, nothing herein shall supersede or modify"
            "      the terms of any separate license agreement you may have executed"
            "      with Licensor regarding such Contributions."
            ""
            "   6. Trademarks. This License does not grant permission to use the trade"
            "      names, trademarks, service marks, or product names of the Licensor,"
            "      except as required for reasonable and customary use in describing the"
            "      origin of the Work and reproducing the content of the NOTICE file."
            ""
            "   7. Disclaimer of Warranty. Unless required by applicable law or"
            "      agreed to in writing, Licensor provides the Work (and each"
            "      Contributor provides its Contributions) on an \"AS IS\" BASIS,"
            "      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or"
            "      implied, including, without limitation, any warranties or conditions"
            "      of TITLE, NON-INFRINGEMENT, MERCHANTABILITY, or FITNESS FOR A"
            "      PARTICULAR PURPOSE. You are solely responsible for determining the"
            "      appropriateness of using or redistributing the Work and assume any"
            "      risks associated with Your exercise of permissions under this License."
            ""
            "   8. Limitation of Liability. In no event and under no legal theory,"
            "      whether in tort (including negligence), contract, or otherwise,"
            "      unless required by applicable law (such as deliberate and grossly"
            "      negligent acts) or agreed to in writing, shall any Contributor be"
            "      liable to You for damages, including any direct, indirect, special,"
            "      incidental, or consequential damages of any character arising as a"
            "      result of this License or out of the use or inability to use the"
            "      Work (including but not limited to damages for loss of goodwill,"
            "      work stoppage, computer failure or malfunction, or any and all"
            "      other commercial damages or losses), even if such Contributor"
            "      has been advised of the possibility of such damages."
            ""
            "   9. Accepting Warranty or Additional Liability. While redistributing"
            "      the Work or Derivative Works thereof, You may choose to offer,"
            "      and charge a fee for, acceptance of support, warranty, indemnity,"
            "      or other liability obligations and/or rights consistent with this"
            "      License. However, in accepting such obligations, You may act only"
            "      on Your own behalf and on Your sole responsibility, not on behalf"
            "      of any other Contributor, and only if You agree to indemnify,"
            "      defend, and hold each Contributor harmless for any liability"
            "      incurred by, or claims asserted against, such Contributor by reason"
            "      of your accepting any such warranty or additional liability."
            ""
            "   END OF TERMS AND CONDITIONS"
            ""
            "   APPENDIX: How to apply the Apache License to your work."
            ""
            "      To apply the Apache License to your work, attach the following"
            "      boilerplate notice, with the fields enclosed by brackets \"[]\""
            "      replaced with your own identifying information. (Don't include"
            "      the brackets!)  The text should be enclosed in the appropriate"
            "      comment syntax for the file format. We also recommend that a"
            "      file or class name and description of purpose be included on the"
            "      same \"printed page\" as the copyright notice for easier"
            "      identification within third-party archives."
            ""
            "   Copyright [yyyy] [name of copyright owner]"
            ""
            "   Licensed under the Apache License, Version 2.0 (the \"License\");"
            "   you may not use this file except in compliance with the License."
            "   You may obtain a copy of the License at"
            ""
            "       http://www.apache.org/licenses/LICENSE-2.0"
            ""
            "   Unless required by applicable law or agreed to in writing, software"
            "   distributed under the License is distributed on an \"AS IS\" BASIS,"
            "   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied."
            "   See the License for the specific language governing permissions and"
            "   limitations under the License.")))

(defun %make-license-string (license)
  (let ((normalized-license (%normalize-license-id license)))
    (cond
      ((string= normalized-license "Apache-2.0")
       (%make-apache-2.0-license-string))
      (t
       (error "[new] unsupported license: ~S" license)))))

;;;; .gitignore
(defun %make-gitignore-string ()
  "*.fasl
*.dx64fsl
*.lx64fsl
.DS_Store
release.md
")

;;;; release.md
(defun %make-release-string ()
  "# TODO: release summary

Describe what changed in this release.

## Changes

- TODO

## Reproducibility

- TODO
")

;;;; help.md
(defun %make-help-string (name)
  (format nil "# ~A Help

Usage:
  taf-~A [-h | --help]
  taf-~A [-v | --version]
  taf-~A [ARGS...]
  taf-~A -- [ARGS...]
  taf-~A --compile [ARGS...]

Options:
  -h, --help       Show this help
  -v, --version    Show package and command version
  --compile        Print generated shell code instead of running it
  --               Pass following arguments to the .taf program
"
          name name name name name name))

;;;; .github/workflows/build-image.yml
(defun %make-github-actions-build-image-workflow-string ()
  (format nil "~{~A~%~}"
          '("name: Build container image"
            ""
            "on:"
            "  push:"
            "    tags:"
            "      - \"v*\""
            "  workflow_dispatch:"
            ""
            "permissions:"
            "  contents: read"
            "  packages: write"
            ""
            "jobs:"
            "  build:"
            "    runs-on: ubuntu-latest"
            "    steps:"
            "      - name: Checkout"
            "        uses: actions/checkout@v4"
            ""
            "      - name: Set up QEMU"
            "        uses: docker/setup-qemu-action@v3"
            ""
            "      - name: Set up Docker Buildx"
            "        uses: docker/setup-buildx-action@v3"
            ""
            "      - name: Read taffish.toml"
            "        id: taffish"
            "        run: |"
            "          python - <<'PY' >> \"$GITHUB_OUTPUT\""
            "          import tomllib"
            "          from pathlib import Path"
            ""
            "          data = tomllib.loads(Path(\"taffish.toml\").read_text())"
            "          container = data.get(\"container\", {})"
            "          image = container.get(\"image\")"
            "          dockerfile = container.get(\"dockerfile\", \"docker/Dockerfile\")"
            "          build_platforms = container.get(\"build_platforms\","
            "                                          container.get(\"platforms\","
            "                                                        \"linux/amd64,linux/arm64\"))"
            "          if not image:"
            "              raise SystemExit(\"missing [container].image in taffish.toml\")"
            "          print(f\"image={image}\")"
            "          print(f\"dockerfile={dockerfile}\")"
            "          print(f\"build_platforms={build_platforms}\")"
            "          print(f\"amd64_image={image}-amd64\")"
            "          print(f\"arm64_image={image}-arm64\")"
            "          PY"
            ""
            "      - name: Log in to GHCR"
            "        uses: docker/login-action@v3"
            "        with:"
            "          registry: ghcr.io"
            "          username: ${{ github.actor }}"
            "          password: ${{ secrets.GITHUB_TOKEN }}"
            ""
            "      - name: Build and push amd64 image"
            "        uses: docker/build-push-action@v6"
            "        with:"
            "          context: ."
            "          file: ${{ steps.taffish.outputs.dockerfile }}"
            "          platforms: linux/amd64"
            "          push: true"
            "          tags: ${{ steps.taffish.outputs.amd64_image }}"
            "          labels: |"
            "            org.opencontainers.image.source=https://github.com/${{ github.repository }}"
            "            org.opencontainers.image.description=TAFFISH app container image"
            ""
            "      - name: Build and push arm64 image"
            "        id: build_arm64"
            "        if: contains(steps.taffish.outputs.build_platforms, 'linux/arm64')"
            "        continue-on-error: true"
            "        uses: docker/build-push-action@v6"
            "        with:"
            "          context: ."
            "          file: ${{ steps.taffish.outputs.dockerfile }}"
            "          platforms: linux/arm64"
            "          push: true"
            "          tags: ${{ steps.taffish.outputs.arm64_image }}"
            "          labels: |"
            "            org.opencontainers.image.source=https://github.com/${{ github.repository }}"
            "            org.opencontainers.image.description=TAFFISH app container image"
            ""
            "      - name: Publish final image manifest"
            "        run: |"
            "          images=\"${{ steps.taffish.outputs.amd64_image }}\""
            "          if [ \"${{ steps.build_arm64.outcome }}\" = \"success\" ]; then"
            "            images=\"$images ${{ steps.taffish.outputs.arm64_image }}\""
            "          else"
            "            echo \"arm64 build did not succeed; publishing amd64-only manifest.\""
            "          fi"
            "          docker buildx imagetools create \\"
            "            -t \"${{ steps.taffish.outputs.image }}\" \\"
            "            $images"
            ""
            "      - name: GHCR visibility note"
            "        run: |"
            "          echo \"::notice title=GHCR visibility::GHCR packages are private by default. If this image should be public, open the package settings on GitHub Packages and change visibility to Public. GitHub does not provide a stable Docker-push switch for this, and public packages cannot be made private again.\"")))

(defun %make-all-default-files (project-dir src-dir docs-dir
                                name tool-or-flow version release
                                license repository-url image docker-p actions-p)
  (%write-string-to-file
   (han.path:join-path project-dir "taffish.toml")
   (%make-taffish-toml-string
    name tool-or-flow version release license repository-url image docker-p))
  (%write-string-to-file
   (han.path:join-path src-dir "main.taf")
   (%make-src-main-string name tool-or-flow version image))
  (when docker-p
    (let ((docker-dir (han.path:join-path project-dir "docker")))
      (%make-dir docker-dir)
      (%write-string-to-file
       (han.path:join-path docker-dir "Dockerfile")
       (%make-dockerfile-string name))))
  (when (and docker-p actions-p)
    (let ((workflow-dir (han.path:join-path project-dir ".github" "workflows")))
      (%make-dir workflow-dir)
      (%write-string-to-file
       (han.path:join-path workflow-dir "build-image.yml")
       (%make-github-actions-build-image-workflow-string))))
  (%write-string-to-file
   (han.path:join-path project-dir "README.md")
   (%make-readme-string name))
  (%write-string-to-file
   (han.path:join-path project-dir "LICENSE")
   (%make-license-string license))
  (%write-string-to-file
   (han.path:join-path project-dir ".gitignore")
   (%make-gitignore-string))
  (%write-string-to-file
   (han.path:join-path project-dir "release.md")
   (%make-release-string))
  (%write-string-to-file
   (han.path:join-path project-dir "target" ".gitkeep")
   "")
  (%write-string-to-file
   (han.path:join-path docs-dir "help.md")
   (%make-help-string name)))

(defun project-new (name args)
  (unless (%valid-project-name-p name)
    (error "[new] invalid project name: ~S~%Project name should use only letters, digits, '-' and '_', and must not start with '-' or '.'."
           name))
  (let* ((args-spec (han.args:parse-args-spec
                     (mapcar #'han.args:parse-arg-spec
                             '("(--/-t)tool?"
                               "(--/-f)flow?"
                               "(--/-v)version=0.1.0"
                               "(--/-r)release=1"
                               "(--/-l)license=Apache-2.0"
                               "(--/-g)repo"
                               "(--/-i)image"
                               "(--/-d)docker?"
                               "(--)no-actions?"))))
         (args-input (han.args:parse-args-input args '("taf-new")))
         (args-result (%check-args-result
                       (han.args:bind-args args-spec args-input)))
         (tool-p (han.args:get-arg "tool" args-result))
         (flow-p (han.args:get-arg "flow" args-result))
         (tool-or-flow (%tool-or-flow tool-p flow-p))
         (version (han.args:get-arg "version" args-result))
         (release (han.args:get-arg "release" args-result))
         (release-number (%parse-positive-integer release "release"))
         (license (%normalize-license-id
                   (han.args:get-arg "license" args-result)))
         (repository-url (or (han.args:get-arg "repo" args-result)
                             (%default-repository-url name)))
         (docker-p (han.args:get-arg "docker" args-result))
         (actions-p (not (han.args:get-arg "no-actions" args-result)))
         (image-p (han.args:get-arg "image" args-result))
         (image (cond (image-p image-p)
                      (docker-p (%default-container-image
                                 name version release-number))
                      (t nil)))
         (work-dir (han.os:current-directory))
         (project-dir (han.path:join-path work-dir name))
         (src-dir    (han.path:join-path project-dir "src"))
         (target-dir (han.path:join-path project-dir "target"))
         (docs-dir   (han.path:join-path project-dir "docs")))
    (when (or (han.path:directory-exists-p (han.path:directory-pathname project-dir))
              (han.path:file-exists-p project-dir))
      (error "[new] project already exists: ~A" project-dir))
    (unless (%valid-version-string-p version)
      (error "[new] version must be a non-empty string without spaces, but got: ~S"
             version))
    (%ensure-repository-url repository-url "[new] --repo")
    (dolist (dir (list project-dir src-dir target-dir docs-dir))
      (%make-dir dir))
    (%make-all-default-files
     project-dir src-dir docs-dir
     name tool-or-flow version release-number license repository-url
     image docker-p actions-p)
    (format t "[TAF] created new ~A project: ~A~%"
            (string-downcase (string tool-or-flow))
            (han.path:->namestring project-dir))))
