#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "rknn_api.h"

typedef int (*rknn_init_fn)(rknn_context *context, void *model, uint32_t size,
			    uint32_t flag, rknn_init_extend *extend);
typedef int (*rknn_set_core_mask_fn)(rknn_context context,
				     rknn_core_mask core_mask);

int rknn_init(rknn_context *context, void *model, uint32_t size,
	      uint32_t flag, rknn_init_extend *extend)
{
	rknn_init_fn real_init;
	rknn_set_core_mask_fn real_set_core_mask;
	const char *value = getenv("RKNN_TEST_CORE_MASK");
	char *end = NULL;
	unsigned long mask;
	int ret;

	*(void **)(&real_init) = dlsym(RTLD_NEXT, "rknn_init");
	if (!real_init) {
		fprintf(stderr, "core-mask preload: cannot resolve rknn_init: %s\n",
			dlerror());
		return -ENOSYS;
	}

	ret = real_init(context, model, size, flag, extend);
	if (ret || !value)
		return ret;

	errno = 0;
	mask = strtoul(value, &end, 0);
	if (errno || !end || *end ||
	    (mask != RKNN_NPU_CORE_0 && mask != RKNN_NPU_CORE_1 &&
	     mask != RKNN_NPU_CORE_2 && mask != RKNN_NPU_CORE_0_1_2)) {
		fprintf(stderr, "core-mask preload: invalid mask '%s'\n", value);
		return -EINVAL;
	}

	*(void **)(&real_set_core_mask) =
		dlsym(RTLD_NEXT, "rknn_set_core_mask");
	if (!real_set_core_mask) {
		fprintf(stderr,
			"core-mask preload: cannot resolve rknn_set_core_mask: %s\n",
			dlerror());
		return -ENOSYS;
	}

	ret = real_set_core_mask(*context, (rknn_core_mask)mask);
	fprintf(stderr, "core-mask preload: mask=%#lx ret=%d\n", mask, ret);
	return ret;
}
