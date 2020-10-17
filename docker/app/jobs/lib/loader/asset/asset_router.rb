# frozen-string-literal: true

require 'loader/asset/asset_loader'
require 'loader/asset/loaders/gcp_loader'
require 'loader/asset/loaders/gcp_iam_loader'
require 'loader/asset/loaders/gcp_iam_roles_loader'
require 'loader/asset/loaders/k8s_loader'

Dir['./app/jobs/lib/loader/asset/loaders/gcp_loader/*.rb'].each { |file| require file }

# Comment
class AssetRouter
  def initialize(asset, import_id, db)
    @asset = asset
    @import_id = import_id
    @db = db
    route
  end

  def route
    # Skip instance templates with an asset name that includes zones
    return if @asset['asset_type'] == 'compute.googleapis.com/InstanceTemplate' && @asset['name'] =~ %r{/zones/}

    # Parse GCP assets (have ancestors block)
    return gcp_load unless @asset['ancestors'].nil?

    # Parse K8s resources
    return k8s_load if @asset['asset_type'].start_with?('k8s.io')

    # Parse built-in IAM Role resources
    return gcp_iam_builtin_role_load if @asset['asset_type'] == 'iam.googleapis.com/ExportedIAMRole'
  end

  private

  def gcp_load
    # GCP CAI K8s resources are incomplete
    return if @asset['asset_type'].start_with?('k8s.io')

    if @asset['iam_policy'].nil?
      # GCP CAI Resource
      GCPLoader.new(@asset, @db, @import_id)
    else
      # GCP CAI IAM
      GCPIAMLoader.new(@asset, @db, @import_id)
    end
  end

  def k8s_load
    # K8s resources
    K8sLoader.new(@asset, @db, @import_id)
  end

  def gcp_iam_builtin_role_load
    # Built-in GCP IAM Roles parsing
    GCPIAMRolesLoader.new(@asset, @db, @import_id)
  end
end
