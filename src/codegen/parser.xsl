<?xml version="1.0"?>
<xsl:stylesheet	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version='1.0'>
	<xsl:template name="parser">
<xsl:document href="g{/format/@format}Parser.cpp" method="text">

#include "<xsl:value-of select="/format/@format"/>.h"
#include "<xsl:value-of select="/format/@format"/>Item.h"
#include "<xsl:value-of select="/format/@format"/>List.h"

namespace <xsl:value-of select="/format/@format"/> {

<xsl:for-each select="type|tag|action|style|stackitem">
//////////////////////////////////// <xsl:value-of select="@name"/>

bool <xsl:value-of select="@name"/>::parse( Reader *r, int end, Context *ctx ) {
	if( ctx->debugTrace ) fprintf( stderr, "PARSE <xsl:value-of select="@name"/> @%i-%i :%i\n", r->getPosition(), r->getBits(), end );
	file_offset = r->getPosition();

	<xsl:apply-templates mode="parse"/>

	<xsl:if test="name()='tag'">
	if( r->getPosition() != file_offset + len ) {
		fprintf( stderr, "WARNING: end of tag <xsl:value-of select="@name"/> is @%i, should be @%i\n", r->getPosition(), file_offset+len );
		r->seekTo( file_offset + len );
	}
	</xsl:if>
	
	return r->getError() == SWFR_OK;
}

</xsl:for-each>

}

</xsl:document>
	</xsl:template>


<xsl:template match="flagged" mode="parse">
	if( <xsl:if test="@negative">!</xsl:if><xsl:value-of select="@flag"/>
		<xsl:if test="@signifier"> &amp; <xsl:value-of select="@signifier"/></xsl:if> ) {
	
		<xsl:apply-templates mode="parse"/>
	} else {
		<xsl:for-each select="*[@default]">
			<xsl:value-of select="@name"/> =  <xsl:value-of select="@default"/>;
		</xsl:for-each>
	}
</xsl:template>

<xsl:template match="if" mode="parse">
	if( ctx->debugTrace ) fprintf( stderr, "PARSE IF <xsl:value-of select="@expression"/> - " );
	if( <xsl:value-of select="@expression"/> ) {
		if( ctx->debugTrace ) fprintf( stderr, "TRUE\n" );
		<xsl:apply-templates mode="parse"/>
	} else {
		if( ctx->debugTrace ) fprintf( stderr, "FALSE\n" );
		<xsl:for-each select="*[@default]">
			<xsl:value-of select="@name"/> =  <xsl:value-of select="@default"/>;
		</xsl:for-each>
	}
</xsl:template>

<xsl:template match="byte|word|fixedpoint|bit|integer|string|uint32|float|double|xml" mode="parse">
	<xsl:value-of select="@name"/> = <xsl:apply-templates select="." mode="get"/>;
	if( ctx->debugTrace ) fprintf( stderr, "PARSE <xsl:value-of select="@name"/>: <xsl:apply-templates select="." mode="printf"/>\n", <xsl:value-of select="@name"/> );
	<xsl:if test="@context">
		ctx-&gt;<xsl:value-of select="@name"/> = <xsl:value-of select="@name"/>;
	</xsl:if>
	<xsl:if test="@next">
		<!-- this describes the offset to end of this object, so we use it for end -->
		if( <xsl:value-of select="@name"/> &amp;&amp; <xsl:value-of select="@name"/>+r->getPosition() &lt; end ) {
			if( ctx->debugTrace ) fprintf(stderr, "- has next offset, setting end to current+%i\n", <xsl:value-of select="@name"/> );
			end = r->getPosition() + <xsl:value-of select="@name"/>
			<xsl:if test="@next-offset"> + (<xsl:value-of select="@next-offset"/>)</xsl:if>;
		}
	</xsl:if>
</xsl:template>
<xsl:template match="byte" mode="get">r->getByte()</xsl:template>
<xsl:template match="word" mode="get">r->getWord()</xsl:template>
<xsl:template match="fixedpoint" mode="get">r->getNBitFixed(<xsl:value-of select="@size"/>,<xsl:value-of select="@exp"/><xsl:if test="@signed">,true</xsl:if>)</xsl:template>
<xsl:template match="uint32" mode="get">r->getInt()</xsl:template>
<xsl:template match="float" mode="get">r->getFloat()</xsl:template>
<xsl:template match="double" mode="get">r->getDouble()</xsl:template>
<xsl:template match="bit" mode="get">r->getNBitInt(1)</xsl:template>
<xsl:template match="integer" mode="get">r->getNBitInt(<xsl:value-of select="@size"/>
			<xsl:if test="@size-add">+<xsl:value-of select="@size-add"/></xsl:if>
			<xsl:if test="@signed">,true</xsl:if>)</xsl:template>
<xsl:template match="string[@mode='pascal']" mode="get">r->getPString()</xsl:template>
<xsl:template match="string" mode="get" priority="-1">r->getString()</xsl:template>
<xsl:template match="xml" mode="get" priority="-1">r->getString()</xsl:template>

<xsl:template match="object" mode="parse">
	<xsl:value-of select="@name"/>.parse(r,end,ctx);
</xsl:template>

<xsl:template match="list[@length]" mode="parse" priority="1">
	{
		if( ctx->debugTrace ) fprintf( stderr, "PARSE list&lt;<xsl:value-of select="@type"/>&gt; <xsl:value-of select="@name"/>: %i items, @%i-%i :%i\n",  <xsl:value-of select="@length"/>, r->getPosition(), r->getBits(), end );
		<xsl:value-of select="@type"/> *item;
		for( int i=0; i&lt;<xsl:value-of select="@length"/>; i++ ) {
			item = <xsl:value-of select="@type"/>::get(r,end,ctx);
			<xsl:value-of select="@name"/>.append( item );
		}
	}
</xsl:template>

<xsl:template match="list" mode="parse" priority="-1">
	{
		if( ctx->debugTrace ) fprintf( stderr, "PARSE list&lt;<xsl:value-of select="@type"/>&gt; <xsl:value-of select="@name"/> @%i-%i :%i\n", r->getPosition(), r->getBits(), end );
		int myend = end;
		<xsl:if test="@end">
			myend = r->getPosition() + <xsl:value-of select="@end"/>
			<xsl:if test="@end-offset"> + (<xsl:value-of select="@end-offset"/>)</xsl:if>;
		</xsl:if>
		
		if( r->getPosition() &lt; myend ) {
			<xsl:value-of select="@type"/> *item;
			item = <xsl:value-of select="@type"/>::get(r,end,ctx);
			while( item &amp;&amp; r->getPosition() &lt;= myend ) {
				<xsl:value-of select="@name"/>.append( item );
				if( r->getPosition() &lt; myend || (r->getPosition()==myend &amp;&amp; r->getBits() ))
					item = <xsl:value-of select="@type"/>::get(r,myend,ctx);
				else item = NULL;
				<xsl:if test="@end-condition">
					if(item &amp;&amp; <xsl:value-of select="@end-condition"/>) {
						<xsl:value-of select="@name"/>.append( item );
						item = NULL;
					}
				</xsl:if>
			}
		}
	}
</xsl:template>

<xsl:template match="data" mode="parse">
	{
		int sz = <xsl:value-of select="@size"/>;

		<xsl:value-of select="@name"/> = new unsigned char[ sz ];
		r->getData( <xsl:value-of select="@name"/>, sz );
	}
</xsl:template>

<xsl:template match="fill-byte" mode="parse">
	r->byteAlign();
</xsl:template>

<xsl:template match="context" mode="parse">
	ctx-><xsl:value-of select="@param"/> = <xsl:value-of select="@value"/>;
</xsl:template>

</xsl:stylesheet>
