 this role required to allow coredns resolve endpoints not available on public resolvers
 need to edit or re-create coredns config map this way:
 EXAMPLE:
           hosts {
             10.99.76.65  iaas152.avntg.cloud.mts.ru
             fallthrough
            }