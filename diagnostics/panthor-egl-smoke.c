// SPDX-License-Identifier: MIT
/*
 * Minimal header-free GBM/EGL/GLES2 smoke test for a DRM render node.
 *
 * It dynamically loads the system libraries, creates a surfaceless GLES2
 * context, clears an off-screen RGBA4 renderbuffer and verifies one pixel.
 * This is intentionally self-contained so it can be cross-compiled without
 * installing graphics development packages on the target.
 */

#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void *EGLDisplay;
typedef void *EGLConfig;
typedef void *EGLContext;
typedef void *EGLSurface;
typedef unsigned int EGLBoolean;
typedef unsigned int EGLenum;
typedef int EGLint;
typedef intptr_t EGLAttrib;

#define EGL_FALSE 0
#define EGL_NONE 0x3038
#define EGL_RED_SIZE 0x3024
#define EGL_GREEN_SIZE 0x3023
#define EGL_BLUE_SIZE 0x3022
#define EGL_ALPHA_SIZE 0x3021
#define EGL_RENDERABLE_TYPE 0x3040
#define EGL_OPENGL_ES2_BIT 0x0004
#define EGL_CONTEXT_CLIENT_VERSION 0x3098
#define EGL_OPENGL_ES_API 0x30a0
#define EGL_PLATFORM_GBM_KHR 0x31d7

#define GL_VENDOR 0x1f00
#define GL_RENDERER 0x1f01
#define GL_VERSION 0x1f02
#define GL_RGBA 0x1908
#define GL_UNSIGNED_BYTE 0x1401
#define GL_COLOR_BUFFER_BIT 0x00004000
#define GL_RENDERBUFFER 0x8d41
#define GL_FRAMEBUFFER 0x8d40
#define GL_COLOR_ATTACHMENT0 0x8ce0
#define GL_RGBA4 0x8056
#define GL_FRAMEBUFFER_COMPLETE 0x8cd5
#define GL_NO_ERROR 0

static void *load_symbol(void *handle, const char *name)
{
	void *symbol = dlsym(handle, name);

	if (!symbol) {
		fprintf(stderr, "missing symbol %s: %s\n", name, dlerror());
		exit(2);
	}

	return symbol;
}

#define LOAD_FN(handle, target) \
	do { *(void **)(&(target)) = load_symbol((handle), #target); } while (0)

int main(int argc, char **argv)
{
	const char *node = argc > 1 ? argv[1] : "/dev/dri/renderD128";
	void *gbm_lib, *egl_lib, *gles_lib, *gbm;
	EGLDisplay display;
	EGLConfig config;
	EGLContext context;
	EGLint major, minor, count;
	unsigned int framebuffer, renderbuffer, status, error;
	unsigned char pixel[4] = { 0, 0, 0, 0 };
	int fd, ok;

	void *(*gbm_create_device)(int);
	void (*gbm_device_destroy)(void *);
	EGLDisplay (*eglGetPlatformDisplay)(EGLenum, void *, const EGLAttrib *);
	EGLBoolean (*eglInitialize)(EGLDisplay, EGLint *, EGLint *);
	EGLBoolean (*eglBindAPI)(EGLenum);
	EGLBoolean (*eglChooseConfig)(EGLDisplay, const EGLint *, EGLConfig *,
				      EGLint, EGLint *);
	EGLContext (*eglCreateContext)(EGLDisplay, EGLConfig, EGLContext,
				       const EGLint *);
	EGLBoolean (*eglMakeCurrent)(EGLDisplay, EGLSurface, EGLSurface,
				     EGLContext);
	EGLBoolean (*eglDestroyContext)(EGLDisplay, EGLContext);
	EGLBoolean (*eglTerminate)(EGLDisplay);
	EGLint (*eglGetError)(void);
	const unsigned char *(*glGetString)(unsigned int);
	void (*glGenFramebuffers)(int, unsigned int *);
	void (*glBindFramebuffer)(unsigned int, unsigned int);
	void (*glGenRenderbuffers)(int, unsigned int *);
	void (*glBindRenderbuffer)(unsigned int, unsigned int);
	void (*glRenderbufferStorage)(unsigned int, unsigned int, int, int);
	void (*glFramebufferRenderbuffer)(unsigned int, unsigned int,
					  unsigned int, unsigned int);
	unsigned int (*glCheckFramebufferStatus)(unsigned int);
	void (*glClearColor)(float, float, float, float);
	void (*glClear)(unsigned int);
	void (*glReadPixels)(int, int, int, int, unsigned int, unsigned int,
			     void *);
	void (*glFinish)(void);
	unsigned int (*glGetError)(void);
	void (*glDeleteRenderbuffers)(int, const unsigned int *);
	void (*glDeleteFramebuffers)(int, const unsigned int *);

	const EGLint config_attributes[] = {
		EGL_RED_SIZE, 4,
		EGL_GREEN_SIZE, 4,
		EGL_BLUE_SIZE, 4,
		EGL_ALPHA_SIZE, 4,
		EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT,
		EGL_NONE
	};
	const EGLint context_attributes[] = {
		EGL_CONTEXT_CLIENT_VERSION, 2,
		EGL_NONE
	};

	fd = open(node, O_RDWR | O_CLOEXEC);
	if (fd < 0) {
		fprintf(stderr, "open %s: %s\n", node, strerror(errno));
		return 1;
	}

	gbm_lib = dlopen("libgbm.so.1", RTLD_NOW | RTLD_LOCAL);
	egl_lib = dlopen("libEGL.so.1", RTLD_NOW | RTLD_LOCAL);
	gles_lib = dlopen("libGLESv2.so.2", RTLD_NOW | RTLD_LOCAL);
	if (!gbm_lib || !egl_lib || !gles_lib) {
		fprintf(stderr, "dlopen graphics libraries: %s\n", dlerror());
		return 2;
	}

	LOAD_FN(gbm_lib, gbm_create_device);
	LOAD_FN(gbm_lib, gbm_device_destroy);
	LOAD_FN(egl_lib, eglGetPlatformDisplay);
	LOAD_FN(egl_lib, eglInitialize);
	LOAD_FN(egl_lib, eglBindAPI);
	LOAD_FN(egl_lib, eglChooseConfig);
	LOAD_FN(egl_lib, eglCreateContext);
	LOAD_FN(egl_lib, eglMakeCurrent);
	LOAD_FN(egl_lib, eglDestroyContext);
	LOAD_FN(egl_lib, eglTerminate);
	LOAD_FN(egl_lib, eglGetError);
	LOAD_FN(gles_lib, glGetString);
	LOAD_FN(gles_lib, glGenFramebuffers);
	LOAD_FN(gles_lib, glBindFramebuffer);
	LOAD_FN(gles_lib, glGenRenderbuffers);
	LOAD_FN(gles_lib, glBindRenderbuffer);
	LOAD_FN(gles_lib, glRenderbufferStorage);
	LOAD_FN(gles_lib, glFramebufferRenderbuffer);
	LOAD_FN(gles_lib, glCheckFramebufferStatus);
	LOAD_FN(gles_lib, glClearColor);
	LOAD_FN(gles_lib, glClear);
	LOAD_FN(gles_lib, glReadPixels);
	LOAD_FN(gles_lib, glFinish);
	LOAD_FN(gles_lib, glGetError);
	LOAD_FN(gles_lib, glDeleteRenderbuffers);
	LOAD_FN(gles_lib, glDeleteFramebuffers);

	gbm = gbm_create_device(fd);
	if (!gbm) {
		fprintf(stderr, "gbm_create_device failed\n");
		return 3;
	}

	display = eglGetPlatformDisplay(EGL_PLATFORM_GBM_KHR, gbm, NULL);
	if (!display || !eglInitialize(display, &major, &minor)) {
		fprintf(stderr, "eglInitialize failed: 0x%x\n", eglGetError());
		return 4;
	}
	if (!eglBindAPI(EGL_OPENGL_ES_API) ||
	    !eglChooseConfig(display, config_attributes, &config, 1, &count) ||
	    count != 1) {
		fprintf(stderr, "EGL config selection failed: 0x%x\n", eglGetError());
		return 5;
	}

	context = eglCreateContext(display, config, NULL, context_attributes);
	if (!context || !eglMakeCurrent(display, NULL, NULL, context)) {
		fprintf(stderr, "surfaceless context failed: 0x%x\n", eglGetError());
		return 6;
	}

	printf("EGL %d.%d\n", major, minor);
	printf("GL_VENDOR=%s\n", glGetString(GL_VENDOR));
	printf("GL_RENDERER=%s\n", glGetString(GL_RENDERER));
	printf("GL_VERSION=%s\n", glGetString(GL_VERSION));

	glGenFramebuffers(1, &framebuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
	glGenRenderbuffers(1, &renderbuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
	glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA4, 4, 4);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
				  GL_RENDERBUFFER, renderbuffer);
	status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	if (status != GL_FRAMEBUFFER_COMPLETE) {
		fprintf(stderr, "framebuffer incomplete: 0x%x\n", status);
		return 7;
	}

	glClearColor(0.25f, 0.50f, 0.75f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	glFinish();
	glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
	glFinish();
	error = glGetError();
	printf("PIXEL=%u,%u,%u,%u GL_ERROR=0x%x\n",
	       pixel[0], pixel[1], pixel[2], pixel[3], error);

	ok = error == GL_NO_ERROR &&
	     pixel[0] >= 48 && pixel[0] <= 80 &&
	     pixel[1] >= 112 && pixel[1] <= 144 &&
	     pixel[2] >= 176 && pixel[2] <= 208 &&
	     pixel[3] >= 240;

	glDeleteRenderbuffers(1, &renderbuffer);
	glDeleteFramebuffers(1, &framebuffer);
	eglMakeCurrent(display, NULL, NULL, NULL);
	eglDestroyContext(display, context);
	eglTerminate(display);
	gbm_device_destroy(gbm);
	close(fd);

	puts(ok ? "RESULT=PASS" : "RESULT=FAIL");
	return ok ? 0 : 8;
}
