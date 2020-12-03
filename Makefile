# Copyright 2017 The Openstack-Helm Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# It's necessary to set this because some environments don't link sh -> bash.
SHELL := /bin/bash
HELM  := helm
TASK  := build

EXCLUDES := tools
CHARTS := $(filter-out $(EXCLUDES), $(patsubst %/.,%,$(wildcard */.)))

.PHONY: $(EXCLUDES) $(CHARTS)

all: $(CHARTS)

$(CHARTS):
	for dir in ceph-osd ceph-client ceph-provisioners ceph-rgw; do \
		cmp ceph-mon/values.yaml $$dir/values.yaml || \
			cp ceph-mon/values.yaml $$dir/values.yaml; \
	done
	@if [ -d $@ ]; then \
		echo; \
		echo "===== Processing [$@] chart ====="; \
		make $(TASK)-$@; \
	fi

init-%:
	$(HELM) dep up $*

lint-%: init-%
	if [ -d $* ]; then $(HELM) lint $*; fi

build-%: lint-%
	if [ -d $* ]; then $(HELM) package $*; fi

clean:
	@echo "Clean all build artifacts"
	rm -f *tgz */charts/*tgz */requirements.lock
	rm -rf */charts */tmpcharts

%:
	@:
