require 'pry'

Puppet::Type.newtype(:multi_rel) do
  desc <<-'ENDOFDESC'
  Like an anchor, but simply for defining multiple relationships, the way
  we used to use collectors before we realized how dangerous they were.

  For example:

      multi_rel { 'internal':
        type         => 'package',
        match        => 'tag',
        pattern      => 'internal',
        relationship => before,
      }

      package { ['foo', 'bar', 'baz']:
        ensure  => present,
        tag     => 'internal',
      }

      yumrepo { 'internal':
        ensure   => 'present',
        baseurl  => 'file:///var/yum/mirror/centos/7/os/x86_64',
        descr    => 'Locally stored packages',
        enabled  => '1',
        gpgcheck => '0',
        priority => '10',
        before   => Multi_rel['internal'],
      }

  ENDOFDESC


  newparam(:type, :namevar => true) do
    desc 'The type of other resource to depend upon'

    munge do |value|
      value.to_s.downcase.to_sym
    end

#     validate do |value|
#       binding.pry
#
#       unless find_resource_type(value)
#         fail Puppet::ParseError, "'#{value}' is not the name of a resource type."
#       end
#     end
  end

  newparam(:match) do
    desc 'The parameter name to match on'

    munge do |value|
      value.to_s.downcase.to_sym
    end
  end

  newparam(:pattern) do
    desc 'A string or regex pattern to match in combination with the match param'
    validate do |value|
      unless [String, Regexp].include?(value.class)
        fail Puppet::ParseError, "Pattern must be a string or regex '#{value}'"
      end
    end
  end

  newparam(:relationship) do
    munge do |value|
      value.to_s.downcase.to_sym
    end

    desc 'The relationship to enforce from this resource to the matched resources'
    validate do |value|
      unless [:before, :require, :subscribe, :notify].include?(value.to_sym)
        fail Puppet::ParseError, "'#{value}' is not a valid relationship"
      end
    end
  end

  # TODO
  newparam(:query) do
    desc 'A hash of matches and patterns to use'
  end

  validate do
    [:match, :pattern, :relationship].each do |param|
      if not self.parameters[param]
        self.fail "Required parameter missing: #{param}"
      end
    end

    unless Puppet::Type.type(self[:type]).valid_parameter? self[:match]
       fail Puppet::ParseError, "The #{self[:type]} type does not have a param of '#{self[:match]}'"
    end
  end

  # OK, this is where it gets gross. Instead of using the new fancy auto* implicit relationship
  # builders, we use the old autorequire and just force our relationships into the catalog. The
  # reason for this is that we want to be able to match based on a pattern, and very old Puppet
  # doesn't have the other auto relationships anyway.
  def autorequire(rel_catalog = nil)
    rel_catalog ||= catalog
    raise(Puppet::DevError, "You cannot add relationship without a catalog") unless rel_catalog

    # TODO: this will only work with native types!
    klass = Puppet::Type.type(self[:type])
    param = self[:match]
    reqs  = super

    rel_catalog.resources.select{|x| x.class == klass}.each do |res|
      next unless (res[param] == self[:pattern] or res[param].include? self[:pattern] or res[param] =~ self[:pattern])

      case self[:relationship]
      when :before
        reqs << Puppet::Relationship::new(self, res)

      when :require
        reqs << Puppet::Relationship::new(res, self)

      when :subscribe
        reqs << Puppet::Relationship::new(self, res)
        #TODO: add refresh

      when :notify
        reqs << Puppet::Relationship::new(res, self)
        #TODO: add refresh

      end
    end
    reqs
  end

  def refresh
    # We don't do anything with them, but we need this to
    #   show that we are "refresh aware" and not break the
    #   chain of propagation.
  end
end
